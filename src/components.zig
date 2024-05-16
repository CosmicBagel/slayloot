const rl = @import("raylib");

// const ColliderBoxComponent = struct {
//     pub fn init() !void {}
//     pub fn update() !void {}
//     pub fn deinit() !void {}
// };

pub const DrawRectangleComponent = struct {
    size: rl.Vector2,
    color: rl.Color,

    pub fn draw(self: DrawRectangleComponent, centerPos: rl.Vector2) void {
        const offsetPos = .{ .x = centerPos.x - self.size.x / 2, .y = centerPos.y - self.size.y / 2 };
        rl.drawRectangleV(offsetPos, self.size, self.color);
    }
};
