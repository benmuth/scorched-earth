const std = @import("std");
const rl = @import("raylib");
const Terrain = @import("terrain.zig").Terrain;

const world_width = 800;
const world_height = 500;
const global_gravity = 1;
const global_speed = 200;
var screen_width: i32 = 1920;
var screen_height: i32 = 1080;

const Tank = struct {
    body: rl.Rectangle = .{ .x = 100, .y = 100, .width = 50, .height = 20 },
    aim_angle: f32 = 0.0,
    power: f32 = 10.0,
    health: u32 = 20,
    color: rl.Color = .red,
    falling: bool = false,
    turn_done: bool = false,

    weapon: Weapon = Weapon{},
    fired: bool = false,
    weapons: [100]Weapon = [1]Weapon{.{}} ** 100, // particles
    num_weapons: u32 = 0,

    pub fn render(self: *Tank) void {
        for (0..self.weapons.len) |i| {
            if (self.weapons[i].is_active) {
                self.weapons[i].render();
            }
        }

        rl.drawRectangleRec(self.body, self.color);
        rl.drawCircle(@intFromFloat(self.body.x), @intFromFloat(self.body.y), 5, .black);
        const start = rl.Vector2{
            .x = self.body.x,
            .y = self.body.y,
        };
        const end = rl.Vector2{
            .x = self.body.x + std.math.cos(self.aim_angle) * 30,
            .y = self.body.y - std.math.sin(self.aim_angle) * 30,
        };
        rl.drawLineEx(
            start,
            end,
            3.0,
            .black,
        );
    }

    pub fn setAimAngle(self: *Tank, angle: f32) void {
        self.aim_angle = std.math.clamp(angle, 0.0, std.math.pi);
    }

    fn setPower(self: *Tank, power: f32) void {
        self.power = std.math.clamp(power, 0.0, 100.0);
    }

    fn setPosition(self: *Tank, terrain: *Terrain, _x: f32, _y: f32) void {
        var temp_body = self.body;
        temp_body.x = _x;
        temp_body.y = _y;
        temp_body.width -= 1;
        temp_body.height -= 1;

        if (terrain.checkCollisionRect(temp_body)) {
            return;
        }

        self.body.x = _x;
        self.body.y = _y;
    }

    fn checkSetFalling(self: *Tank, world: *World) void {
        const y_start: f32 = self.body.y + self.body.height;
        const x_start: f32 = self.body.x;
        const x_end: f32 = self.body.x + self.body.width;

        var x = x_start;
        while (x < x_end) : (x += 1) {
            if (world.terrain.getTerrainWorld(x, y_start) > 0) {
                self.falling = false;
                return;
            }
        }
        self.falling = true;
    }

    pub fn update(self: *Tank, world: *World) void {
        const delta_time = rl.getFrameTime();
        for (0..self.num_weapons) |i| {
            if (self.weapons[i].is_active) {
                self.weapons[i].update(world);
            }
        }

        for (0..self.num_weapons) |i| {
            if (self.weapons[i].is_active == false) {
                self.weapons[i] = self.weapons[self.num_weapons - 1];
                self.num_weapons -= 1;
            }
        }
        self.checkSetFalling(world);

        if (self.falling) {
            self.setPosition(&(world.*.terrain), self.body.x, self.body.y + 1);
            return;
        }

        if (self.fired == true) {
            // return;
        }

        if (&world.tanks[world.active_tank] != self) {
            return;
        }

        if (rl.isKeyDown(.right)) {
            self.setPosition(&(world.*.terrain), self.body.x + global_speed * delta_time, self.body.y);
        } else if (rl.isKeyDown(.left)) {
            self.setPosition(&(world.*.terrain), self.body.x - global_speed * delta_time, self.body.y);
        }

        const aim_speed = 3.0 * delta_time;

        if (rl.isKeyDown(.down)) {
            self.setAimAngle(self.aim_angle - aim_speed);
        } else if (rl.isKeyDown(.up)) {
            self.setAimAngle(self.aim_angle + aim_speed);
        }

        const power_speed = 50.0 * delta_time;

        if (rl.isKeyDown(.w)) {
            if (world.sound2) |s| {
                if (!rl.isSoundPlaying(s)) {
                    rl.playSound(s);
                }
            }
            self.setPower(self.power + power_speed);
        } else if (rl.isKeyDown(.s)) {
            if (world.sound2) |s| {
                if (!rl.isSoundPlaying(s)) {
                    rl.playSound(s);
                }
            }
            self.setPower(self.power - power_speed);
        }

        if (rl.isKeyReleased(.space)) {
            const gun_end = rl.Vector2{
                .x = self.body.x + std.math.cos(self.aim_angle) * 30,
                .y = self.body.y - std.math.sin(self.aim_angle) * 30,
            };
            const initial_velocity: rl.Vector2 = .{
                .x = 50 * self.power * std.math.cos(self.aim_angle),
                .y = 50 * self.power * -std.math.sin(self.aim_angle),
            };

            self.fired = true;
            Weapon.fire(world, self, gun_end, initial_velocity);
        }
    }
};

const Weapon = struct {
    position: rl.Vector2 = .{ .x = 0, .y = 0 },
    radius: f32 = 10.0,
    body: rl.Rectangle = .{ .x = 0, .y = 0, .width = 5, .height = 5 },
    velocity: rl.Vector2 = .{ .x = 0, .y = 0 },
    is_active: bool = false,
    is_exploding: bool = false,
    next_turn: bool = false,
    tank_id: usize = 0,
    particles: u32 = 1,

    fn fire(world: *World, tank: *Tank, gun_end: rl.Vector2, initial_velocity: rl.Vector2) void {
        const weapon: Weapon = .{
            .position = gun_end,
            .radius = 2.0,
            .body = .{ .x = gun_end.x, .y = gun_end.y, .width = 5, .height = 5 },
            .velocity = initial_velocity,
            .tank_id = world.active_tank,
            .is_active = true,
        };

        tank.weapons[tank.num_weapons] = weapon;
        tank.num_weapons += 1;
        if (world.sound) |s| {
            rl.playSound(s);
        }

        // std.log.debug("status: {}", .{weapon.is_active});
    }

    fn render(self: *Weapon) void {
        rl.drawRectangleLinesEx(self.body, 1, .black);
        rl.drawCircleV(self.position, self.radius, .red);
    }

    fn checkCollision(self: *Weapon, world: *World) void {
        const width: f32 = @floatFromInt(world.terrain.width);
        const height: f32 = @floatFromInt(world.terrain.height);

        if (self.position.x < 0 or self.position.x > width or
            self.position.y < 0 or self.position.y > height)
        {
            self.is_active = false;
            return;
        }

        for (0..world.tanks.len) |i| {
            const tank_to_check = &world.tanks[i];
            const direct_collide = rl.checkCollisionCircleRec(self.position, self.radius, tank_to_check.body);
            if (direct_collide) {
                self.explode(world);
                return;
            }
        }
        if (world.terrain.checkCollisionCircle(self.position, self.radius)) {
            self.explode(world);
            return;
        }
    }

    fn update(self: *Weapon, world: *World) void {
        const delta_time = rl.getFrameTime();

        self.body.x += self.velocity.x * delta_time;
        self.body.y += self.velocity.y * delta_time;

        self.position = self.position.add(self.velocity.scale(delta_time));

        self.velocity.y += 3000 * delta_time;

        self.checkCollision(world);
    }

    fn explode(self: *Weapon, world: *World) void {
        const radius: u32 = 25;

        world.terrain.setTerrainCircle(self.position, radius, 0);

        for (0..world.tanks.len) |i| {
            if (rl.checkCollisionCircleRec(self.position, radius, world.tanks[i].body)) {
                world.tanks[i].health -= 10;
                std.log.debug("health: {d}", .{world.tanks[i].health});
            }
        }

        self.is_active = false;
        self.is_exploding = false;
        world.active_tank = (world.active_tank + 1) % (world.tanks.len);
        world.tanks[world.active_tank].fired = false;
        std.log.debug("world.active_tank: {d}", .{world.active_tank});
    }
};

const World = struct {
    // sound: ?rl.Sound = null,
    // sound2: ?rl.Sound = null,
    game_state: GameState = .Menu,
    terrain: Terrain = undefined,
    tanks: [2]Tank = [_]Tank{
        Tank{ .color = .red },
        Tank{ .color = .yellow },
    },

    active_tank: usize = 0,
    camera: rl.Camera2D = .{
        .offset = .{ .x = 0, .y = world_height },
        .target = .{ .x = 0, .y = world_height / 2 },
        .rotation = 0.0,
        .zoom = 2.0,
    },

    pub fn init(self: *World) void {
        // self.sound = null;
        self.terrain.init(world_width, world_height, std.heap.page_allocator) catch unreachable;
        self.terrain.fillHalf(1);
        self.tanks[0].body.x = 100;
        self.tanks[0].body.y = 500 / 2 - 20;
        self.tanks[1].body.x = 400;
        self.tanks[1].body.y = 500 / 2 - 20;
    }

    fn update(self: *World) void {
        for (0..self.tanks.len) |i| {
            self.tanks[i].update(self);
        }

        for (0..self.tanks.len) |i| {
            if (self.tanks[i].health <= 0) {
                std.log.debug("Tank {d} is destroyed!", .{i});
                self.game_state = .GameOver;
            }
        }

        self.terrain.update();
    }

    pub fn render(self: *World) void {
        self.terrain.pre_render();

        rl.beginDrawing();
        rl.beginMode2D(self.camera);
        // rl.clearBackground(.white);
        self.terrain.render();
        for (&self.tanks) |*tank| {
            tank.render();
        }

        const text = rl.textFormat(
            "angle: %.2f, power: %.2f\n",
            .{ self.tanks[self.active_tank].aim_angle, self.tanks[self.active_tank].power },
        );
        rl.drawText(text, 0, 0, 15, .black);
        rl.endMode2D();

        rl.endDrawing();
    }
};

const GameState = enum {
    Menu,
    Playing,
    Paused,
    GameOver,
};

pub fn main() anyerror!void {
    rl.setConfigFlags(.{ .window_resizable = true, .window_highdpi = true });
    rl.initWindow(screen_width, screen_height, "Scorched Earth");
    defer rl.closeWindow();
    rl.setTargetFPS(120);

    // rl.initAudioDevice();

    // const canon = try rl.loadSound("assets/canon_fire.ogg"); // Preload sound
    // const click = try rl.loadSound("assets/click_sound.wav"); // Preload sound

    var world: World = .{};
    world.init();
    // world.sound = canon;
    // world.sound2 = click;

    var gamestate = GameState.Menu;
    _ = &gamestate;

    // Main game loop
    while (!rl.windowShouldClose()) {
        switch (world.game_state) {
            .Menu => {
                rl.beginDrawing();
                rl.clearBackground(.blue);
                rl.drawText("Press ENTER to Start", 10, 10, 10, .white);
                // rl.drawCircle(100, 100, 1000, rl.Color.white);
                rl.endDrawing();
                if (rl.isKeyPressed(.enter)) {
                    world.game_state = .Playing;
                }
            },
            .Playing => {
                world.update();
                world.render();
            },
            .Paused => {},
            .GameOver => {
                rl.beginDrawing();
                // rl.clearBackground(.blue);
                rl.drawText("Game Over", @divTrunc(screen_width, 2), @divTrunc(screen_height, 2), 50, .white);
                rl.endDrawing();
            },
        }
        // rl.endDrawing();
    }
}
