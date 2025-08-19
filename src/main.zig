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

    pub fn update(self: *Tank, world: *World) void {
        if (rl.isKeyDown(.right)) {
            self.body.x += global_speed;
        } else if (rl.isKeyDown(.left)) {
            self.body.x -= global_speed;
        }

        if (rl.isKeyDown(.up)) {
            self.setAimAngle(self.aim_angle + 0.25);
        } else if (rl.isKeyDown(.down)) {
            self.setAimAngle(self.aim_angle - 0.25);
        }

        if (rl.isKeyReleased(.space)) {
            const gun_end = rl.Vector2{
                .x = self.body.x + std.math.cos(self.aim_angle) * 30,
                .y = self.body.y - std.math.sin(self.aim_angle) * 30,
            };
            Weapon.fire(world, gun_end);
        }
    }
};

const Weapon = struct {
    body: rl.Rectangle = .{ .x = 0, .y = 0, .width = 5, .height = 5 },
    velocity: rl.Vector2 = .{ .x = 20, .y = 10 },
    is_active: bool = false,

    fn fire(world: *World, gun_end: rl.Vector2) void {
        const weapon: Weapon = .{
            .body = .{ .x = gun_end.x, .y = gun_end.y, .width = 5, .height = 5 },
        };
        world.weapons[world.num_weapons] = weapon;

        world.num_weapons += 1;
    }

    fn render(self: *Weapon) void {
        rl.drawRectangleRec(self.body, .black);
    }

    fn update(self: *Weapon) void {
        self.body.x += self.velocity.x;
        self.body.y += self.velocity.y;

        self.velocity.y += 1;
    }
};

const World = struct {
    terrain: Terrain = Terrain{},
    tanks: [2]Tank = [_]Tank{
        Tank{ .color = .red },
        Tank{ .color = .yellow },
    },

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
        for (&self.tanks) |*tank| {
            tank.update(self);
        }
        for (0..self.num_weapons) |i| {
            self.weapons[i].update();
        }
    }

    pub fn render(self: *World) void {
        self.terrain.render();
        for (self.tanks) |tank| {
            tank.render();
        }
        for (0..self.num_weapons) |i| {
            self.weapons[i].render();
        }
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
        //----------------------------------------------------------------------------------
    }
}
