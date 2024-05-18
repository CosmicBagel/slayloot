const rl = @import("raylib");

const cp = @cImport({
    @cInclude("chipmunk/chipmunk.h");
});

pub const Wall = struct {
    pos: rl.Vector2,
    size: rl.Vector2,
    color: rl.Color,
    cpShape: *cp.cpShape,

    const colors = [_]rl.Color{
        rl.Color.dark_gray,
        rl.Color.light_gray,
        rl.Color.gray,
        rl.Color.orange,
    };

    pub fn init(space: *cp.struct_cpSpace, pos: rl.Vector2, size: rl.Vector2, color: rl.Color) !Wall {
        const radius = 0;

        //cpSpaceAddBody returns the same pointer we pass in... idk why
        const body = cp.cpSpaceGetStaticBody(space) orelse return error.GenericError;
        // _ = cp.cpSpaceAddBody(space, body) orelse return error.GenericError;

        cp.cpBodySetPosition(body, cp.cpv(pos.x, pos.y));

        const shape = cp.cpBoxShapeNew(body, size.x, size.y, radius) orelse return error.GenericError;
        //cpSpaceAddShape also returns the same pointer we pass in...
        _ = cp.cpSpaceAddShape(space, shape) orelse return error.GenericError;

        return Wall{
            .pos = pos,
            .size = size,
            .color = color,
            .cpShape = shape,
        };
    }

    pub fn draw(self: Wall) void {
        // rl.drawRectangleV(self.pos, self.size, self.color);
        const offsetPos = .{
            .x = self.pos.x - self.size.x / 2,
            .y = self.pos.y - self.size.y / 2,
        };
        rl.drawRectangleV(offsetPos, self.size, self.color);
    }

    pub fn update(_: *Wall) void {
        // const newPos = cp.cpBodyGetPosition(self.cpBody);
        // self.pos = .{ .x = @floatCast(newPos.x), .y = @floatCast(newPos.y) };
    }

    pub fn deinitWalls(buffer: []Wall) void {
        for (buffer) |*wall| {
            wall.deinit();
        }
    }

    pub fn deinit(self: *Wall) void {
        cp.cpShapeFree(self.cpShape);
    }

    pub fn generateWalls(buffer: []Wall, space: *cp.struct_cpSpace, width: comptime_int, height: comptime_int) !void {
        const side = enum { top, left, right, bottom };

        var current_side = side.top;
        var side_count: u32 = 0;
        const side_size = height - 2; //- 2 for top and bottom walls

        for (buffer, 0..) |*wall, i| {
            var pos: rl.Vector2 = rl.Vector2.init(0, 0);
            switch (current_side) {
                .top => {
                    const x_pos: f32 = @floatFromInt(side_count * 25);
                    pos = .{ .x = x_pos, .y = 0 };
                    if (side_count + 1 == width) {
                        current_side = .bottom;
                        side_count = 0;
                    }
                },
                .bottom => {
                    const x_pos: f32 = @floatFromInt(side_count * 25);
                    const y_pos: f32 = @floatFromInt((height - 1) * 25);
                    pos = .{ .x = x_pos, .y = y_pos };
                    if (side_count + 1 == width) {
                        current_side = .left;
                        side_count = 0;
                    }
                },
                .left => {
                    const y_pos: f32 = @floatFromInt(side_count * 25);
                    const x_pos: f32 = 0;
                    pos = .{ .x = x_pos, .y = y_pos };
                    if (side_count + 1 == side_size) {
                        current_side = .right;
                        side_count = 0;
                    }
                },
                .right => {
                    const y_pos: f32 = @floatFromInt(side_count * 25);
                    const x_pos: f32 = @floatFromInt((width - 1) * 25);
                    pos = .{ .x = x_pos, .y = y_pos };
                },
            }

            const size = .{ .x = 25, .y = 25 };
            const color = colors[i % colors.len];
            wall.* = try init(space, pos, size, color);

            side_count += 1;
        }
    }
};
