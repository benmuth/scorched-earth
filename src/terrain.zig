const std = @import("std");
const rl = @import("raylib");

const TerrainType = enum(u32) {
    Empty = 0,
    Ground = 0x00FF00FF,
};

pub const Terrain = struct {
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

        std.log.debug("Terrain initialized: {d}x{d}\n", .{ width, height });
    }

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

    pub fn pre_render(self: *Terrain) void {
        // std.log.debug("Rendering terrain...\n", .{});

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const color: u32 = if (self.getTerrain(x, y).* == 1) 0xFF30E400 else 0xFFFFF179;
                self.texture_data[y * self.width + x] = color;
            }
        }

        rl.updateTexture(self.texture.texture, self.texture_data.ptr);
    }

    pub fn render(self: *Terrain) void {
        rl.drawTexture(self.texture.texture, 1, 1, .white);
    }
};
