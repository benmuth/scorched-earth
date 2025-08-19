const std = @import("std");
const rl = @import("raylib");

const world_width = 800;
const world_height = 500;
const global_gravity = 1;
const global_speed = 10;

const Terrain = struct {
    width: u32 = world_width,
    height: u32 = world_height,
    data: [world_width * world_height]u32 = [_]u32{0} ** (world_width * world_height),

    pub fn fillHalf(self: *Terrain, t_type: u32) void {
        const half_height = self.height / 2;
        @memset(self.data[0 .. self.width * self.height], 0);

        for (half_height..self.height) |y| {
            for (0..self.width) |x| {
                self.getTerrain(x, y).* = t_type;
            }
        }
    }

    pub fn getTerrain(self: *Terrain, x: usize, y: usize) *u32 {
        if (x >= self.width or y >= self.height) {
            std.debug.assert(false);
        }
        return &self.data[y * self.width + x];
    }

    pub fn render(self: *Terrain) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const color: rl.Color = if (self.getTerrain(x, y).* == 1) .green else .blue;
                rl.drawPixel(@intCast(x), @intCast(y), color);
            }
        }
    }
};

const Tank = struct {
    body: rl.Rectangle = .{ .x = 100, .y = 100, .width = 50, .height = 20 },
    aim_angle: f32 = 0.0,
    power: f32 = 10.0,
    health: u32 = 100,
    color: rl.Color = .red,

    pub fn render(self: *const Tank) void {
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

        // std.log.debug("Tank at ({d:.2}, {d:.2}), aim angle: {d:.2}", .{
        //     self.body.x,
        //     self.body.y,
        //     self.aim_angle,
        // });
    }

    pub fn setAimAngle(self: *Tank, angle: f32) void {
        self.aim_angle = std.math.clamp(angle, 0.0, std.math.pi);
    }

    fn setPower(self: *Tank, power: f32) void {
        self.power = std.math.clamp(power, 0.0, 100.0);
    }

    pub fn update(self: *Tank, world: *World) void {
        if (rl.isKeyDown(.right)) {
            self.body.x += global_speed;
        } else if (rl.isKeyDown(.left)) {
            self.body.x -= global_speed;
        }

        if (rl.isKeyDown(.down)) {
            self.setAimAngle(self.aim_angle - 0.25);
        } else if (rl.isKeyDown(.up)) {
            self.setAimAngle(self.aim_angle + 0.25);
        }

        if (rl.isKeyDown(.w)) {
            self.setPower(self.power + 0.5);
        } else if (rl.isKeyDown(.s)) {
            self.setPower(self.power - 0.5);
        }

        if (rl.isKeyReleased(.space)) {
            const gun_end = rl.Vector2{
                .x = self.body.x + std.math.cos(self.aim_angle) * 30,
                .y = self.body.y - std.math.sin(self.aim_angle) * 30,
            };
            const initial_velocity: rl.Vector2 = .{
                .x = self.power * std.math.cos(self.aim_angle),
                .y = self.power * -std.math.sin(self.aim_angle),
            };

            Weapon.fire(world, gun_end, initial_velocity);
        }
    }
};

const Weapon = struct {
    body: rl.Rectangle = .{ .x = 0, .y = 0, .width = 5, .height = 5 },
    velocity: rl.Vector2 = .{ .x = 0, .y = 0 },
    is_active: bool = true,
    is_exploding: bool = false,

    fn fire(world: *World, gun_end: rl.Vector2, initial_velocity: rl.Vector2) void {
        const weapon: Weapon = .{
            .body = .{ .x = gun_end.x, .y = gun_end.y, .width = 5, .height = 5 },
            .velocity = initial_velocity,
        };
        world.weapons[world.num_weapons] = weapon;
        std.log.debug("status: {}", .{weapon.is_active});

        world.num_weapons += 1;
    }

    fn render(self: *Weapon) void {
        rl.drawRectangleRec(self.body, .black);
    }

    fn checkCollision(self: *Weapon, world: *World) void {
        for (0..world.tanks.len) |i| {
            if (i != world.active_tank) {
                const tank_to_check = &world.tanks[i];
                const direct_collide = rl.checkCollisionRecs(self.body, tank_to_check.body);
                if (direct_collide) {
                    self.explode(world);
                }
            }
        }
        for (0..world.terrain.height) |y| {
            for (0..world.terrain.width) |x| {
                if (world.terrain.getTerrain(x, y).* > 0) {
                    if (rl.checkCollisionPointRec(.{ .x = @floatFromInt(x), .y = @floatFromInt(y) }, self.body)) {
                        self.explode(world);
                        return;
                    }
                }
            }
        }
    }

    fn update(self: *Weapon, world: *World) void {
        self.body.x += self.velocity.x;
        self.body.y += self.velocity.y;

        self.velocity.y += 1;

        self.checkCollision(world);
    }

    fn explode(self: *Weapon, world: *World) void {
        const radius: u32 = 20;
        const x_start: usize = @intFromFloat(self.body.x - radius);
        const y_start: usize = @intFromFloat(self.body.y - radius);

        for (y_start..y_start + 2 * radius) |y| {
            for (x_start..x_start + 2 * radius) |x| {
                world.terrain.getTerrain(x, y).* = 0;
            }
        }

        for (0..world.tanks.len) |i| {
            if (i != world.active_tank) {
                const blast: rl.Rectangle = .{ .x = @floatFromInt(x_start), .y = @floatFromInt(y_start), .height = radius * 2, .width = radius * 2 };
                if (rl.checkCollisionRecs(blast, world.tanks[i].body)) {
                    world.tanks[i].health -= 10;
                    std.log.debug("health: {d}", .{world.tanks[i].health});
                }
            }
        }

        self.is_active = false;
        self.is_exploding = false;
    }
};

const World = struct {
    terrain: Terrain = Terrain{},
    tanks: [2]Tank = [_]Tank{
        Tank{ .color = .red },
        Tank{ .color = .yellow },
    },

    active_tank: usize = 0,

    num_weapons: u32 = 0,
    weapons: [100]Weapon = [1]Weapon{.{}} ** 100,

    pub fn init(self: *World) void {
        self.terrain.fillHalf(1);
        self.tanks[0].body.x = 100;
        self.tanks[0].body.y = 500 / 2 - 20;
        self.tanks[1].body.x = 400;
        self.tanks[1].body.y = 500 / 2 - 20;
    }

    fn update(self: *World) void {
        // for (&self.tanks) |*tank| {
        //     tank.update(self);
        // }

        self.tanks[self.active_tank].update(self);
        for (0..self.num_weapons) |i| {
            if (self.weapons[i].is_active) self.weapons[i].update(self);
        }
    }

    pub fn render(self: *World) void {
        self.terrain.render();
        for (self.tanks) |tank| {
            tank.render();
        }
        for (0..self.num_weapons) |i| {
            if (self.weapons[i].is_active) self.weapons[i].render();
        }

        const text = rl.textFormat(
            "angle: %.2f, power: %.2f\n",
            .{ self.tanks[self.active_tank].aim_angle, self.tanks[self.active_tank].power },
        );
        rl.drawText(text, 0, 0, 15, .black);
    }
};

pub fn main() anyerror!void {
    rl.initWindow(world_width, world_height, "Scorched Earth");
    defer rl.closeWindow();
    rl.setTargetFPS(120);

    var world: World = .{};
    world.init();

    // Main game loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(.white);

        world.update();

        world.render();

        rl.endDrawing();
    }
}
