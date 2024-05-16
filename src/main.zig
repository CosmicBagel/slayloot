const std = @import("std");
const rl = @import("raylib");

const cp = @cImport({
    @cInclude("chipmunk/chipmunk.h");
});

const sl = struct {
    usingnamespace @import("player.zig");
    usingnamespace @import("wall.zig");
    usingnamespace @import("components.zig");
};

pub fn main() !void {
    //raylib init
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "slayloot");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // init physics
    const space = cp.cpSpaceNew() orelse return error.GenericError;
    defer cp.cpSpaceFree(space);
    const gravity = cp.cpv(0, 0);
    cp.cpSpaceSetGravity(space, gravity);
    cp.cpSpaceSetDamping(space, 1); // min damp

    // init game objects
    var p = try sl.Player.init(space);
    defer p.deinit();

    var walls: [42]sl.Wall = undefined;
    try sl.Wall.generateWalls(&walls, space, 16, 8);
    defer sl.Wall.deinitWalls(&walls);

    // game loop
    while (!rl.windowShouldClose() and rl.isKeyUp(rl.KeyboardKey.key_q)) {
        // physics tick here
        cp.cpSpaceStep(space, rl.getFrameTime());

        // update game objects
        p.update();
        for (&walls) |*wall| {
            wall.update();
        }

        // draw game objects
        rl.beginDrawing();
        defer rl.endDrawing();

        p.draw();

        for (walls) |wall| {
            wall.draw();
        }

        rl.clearBackground(rl.Color.white);
        rl.drawText("dungeon time", 190, 200, 20, rl.Color.light_gray);
    }
}

fn updateAnyType(gameObj: anytype) void {
    comptime switch (@typeInfo(@TypeOf(gameObj))) {
        .Pointer => {},
        else => @compileError("Why u no pass pointer?"),
    };
    gameObj.update();
}

fn normalize2d(vec: rl.Vector2) rl.Vector2 {
    var out = vec;
    var mag: f32 = std.math.sqrt(vec.x * vec.x + vec.y * vec.y);
    mag = if (mag == 0) 1.0 else mag;

    out.x /= mag;
    out.y /= mag;

    return out;
}
