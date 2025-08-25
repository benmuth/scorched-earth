const std = @import("std");
const rl = @import("raylib");

const TerrainType = enum(u32) {
    Empty = 0,
    Ground = 0x00FF00FF,
};

pub const Terrain = struct {
    world_origin_x: f32 = 0,
    world_origin_y: f32 = 0,

    width: u32 = 0,
    height: u32 = 0,
    data: []u32,
    texture_data: []u32,
    texture: rl.RenderTexture2D = undefined,

    pub fn init(self: *Terrain, width: u32, height: u32, allocator: std.mem.Allocator) !void {
        self.width = width;
        self.height = height;
        self.data = try allocator.alloc(u32, width * height);
        self.texture_data = try allocator.alloc(u32, width * height);
        self.texture = try rl.RenderTexture2D.init(@intCast(width), @intCast(height));
        std.log.debug("texture format: {}\n", .{self.texture.texture.format});
        // self.texture.texture.format = rl.PixelFormat.uncompressed_r8g8b8a8;
        self.fillHalf(1);

        self.world_origin_x = 0;
        self.world_origin_y = 0;

        std.log.debug("Terrain initialized: {d}x{d}\n", .{ width, height });
    }

    pub fn worldToIndex(self: *Terrain, world_x: f32, world_y: f32) ?usize {
        if (world_x < self.world_origin_x or world_y < self.world_origin_y) {
            return null;
        }
        if (world_x >= self.world_origin_x + @as(f32, @floatFromInt(self.width)) or world_y >= self.world_origin_y + @as(f32, @floatFromInt(self.height))) {
            return null;
        }
        const local_x: usize = @intFromFloat(world_x - self.world_origin_x);
        const local_y: usize = @intFromFloat(world_y - self.world_origin_y);

        return local_y * self.width + local_x;
    }

    pub fn fillHalf(self: *Terrain, t_type: u32) void {
        @memset(self.data[0 .. self.width * self.height], 0);

        const half_height = self.height / 2;

        for (half_height..self.height) |y| {
            for (0..self.width) |x| {
                self.setTerrain(x, y, t_type);
            }
        }
    }

    pub fn setTerrainRect(self: *Terrain, _x: usize, _y: usize, w: usize, h: usize, t_type: u32) void {
        for (_y.._y + h) |y| {
            for (_x.._x + w) |x| {
                self.setTerrain(x, y, t_type);
            }
        }
    }

    pub fn checkCollisionRect(self: *Terrain, rect: rl.Rectangle) bool {
        var body = rect;
        body.x -= self.world_origin_x;
        body.y -= self.world_origin_y;

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                if (self.getTerrain(x, y) > 0) {
                    const terrain_rect = rl.Rectangle{
                        .x = @floatFromInt(x),
                        .y = @floatFromInt(y),
                        .width = 1,
                        .height = 1,
                    };
                    if (rl.checkCollisionRecs(body, terrain_rect)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    pub fn setTerrainWorld(self: *Terrain, world_x: f32, world_y: f32, t_type: u32) void {
        const index = self.worldToIndex(world_x, world_y);
        if (index) |i| {
            self.setTerrainIndex(i, t_type);
        }
    }

    pub fn getTerrainWorld(self: *Terrain, world_x: f32, world_y: f32) u32 {
        const index = self.worldToIndex(world_x, world_y);
        if (index) |i| {
            return self.getTerrainIndex(i);
        } else {
            unreachable;
        }
    }

    pub fn setTerrainIndex(self: *Terrain, index: usize, t_type: u32) void {
        if (index >= self.width * self.height) {
            return;
        }
        self.data[index] = t_type;
    }

    pub fn getTerrainIndex(self: *Terrain, index: usize) u32 {
        if (index >= self.width * self.height) {
            return 0;
        }
        return self.data[index];
    }

    fn setTerrain(self: *Terrain, x: usize, y: usize, t_type: u32) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) {
            return;
        }
        self.data[y * self.width + x] = t_type;
    }

    pub fn getTerrain(self: *Terrain, x: usize, y: usize) u32 {
        if (x >= self.width or y >= self.height) {
            std.debug.assert(false);
        }
        return self.data[y * self.width + x];
    }

    pub fn pre_render(self: *Terrain) void {
        // std.log.debug("Rendering terrain...\n", .{});

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const color: u32 = if (self.getTerrain(x, y) == 1) 0xFF30E400 else 0xFFFFF179;
                self.texture_data[y * self.width + x] = color;
            }
        }

        rl.updateTexture(self.texture.texture, self.texture_data.ptr);
    }

    pub fn render(self: *Terrain) void {
        rl.drawTexture(self.texture.texture, 1, 1, .white);
    }
};
