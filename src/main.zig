const std = @import("std");
const rl = @import("raylib");

const cp = @cImport({
    @cInclude("chipmunk/chipmunk.h");
});

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
    var p = try Player.init(space);
    defer p.deinit();

    var walls: [42]Wall = undefined;
    try Wall.generateWalls(&walls, space, 16, 8);
    defer Wall.deinitWalls(&walls);

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

// const ColliderBoxComponent = struct {
//     fn init() !void {}
//     fn update() !void {}
//     fn deinit() !void {}
// };

const DrawRectangleComponent = struct {
    size: rl.Vector2,
    color: rl.Color,

    fn draw(self: DrawRectangleComponent, centerPos: rl.Vector2) void {
        const offsetPos = .{ .x = centerPos.x - self.size.x / 2, .y = centerPos.y - self.size.y / 2 };
        rl.drawRectangleV(offsetPos, self.size, self.color);
    }
};

const Player = struct {
    centerPos: rl.Vector2,
    speed: f64,
    rect: DrawRectangleComponent,
    cpBody: *cp.cpBody,
    cpShape: *cp.cpShape,

    const mass = 80;
    const width = 25;
    const height = 25;
    const radius = 30;

    fn init(space: *cp.struct_cpSpace) !Player {
        const rect = .{ .size = .{ .x = 25, .y = 25 }, .color = rl.Color.dark_green };
        const pos = .{ .x = 50, .y = 50 };
        const speed = 250;

        const moment = cp.cpMomentForBox(mass, width, height);
        const body = cp.cpBodyNew(mass, moment) orelse return error.GenericError;

        //cpSpaceAddBody returns the same pointer we pass in... idk why
        _ = cp.cpSpaceAddBody(space, body) orelse return error.GenericError;

        cp.cpBodySetPosition(body, cp.cpv(pos.x, pos.y));

        const shape = cp.cpBoxShapeNew(body, width, height, radius) orelse return error.GenericError;
        //cpSpaceAddShape also returns the same pointer we pass in...
        _ = cp.cpSpaceAddShape(space, shape) orelse return error.GenericError;

        return Player{ .rect = rect, .centerPos = pos, .speed = speed, .cpBody = body, .cpShape = shape };
    }

    fn update(self: *Player) void {
        const newPos = cp.cpBodyGetPosition(self.cpBody);
        self.centerPos = .{ .x = @floatCast(newPos.x), .y = @floatCast(newPos.y) };

        var moveVec = cp.cpVect {.x = 0, .y = 0};
        if (rl.isKeyDown(rl.KeyboardKey.key_w)) {
            moveVec.y -= 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_s)) {
            moveVec.y += 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_d)) {
            moveVec.x += 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_a)) {
            moveVec.x -= 1;
        }

        moveVec = cp.cpvnormalize(moveVec);
        moveVec = cp.cpvmult(moveVec, self.speed);

        cp.cpBodySetVelocity(self.cpBody, moveVec);
    }

    fn draw(self: Player) void {
        self.rect.draw(self.centerPos);
    }

    fn deinit(self: *Player) void {
        // clean up cpShapes first then cpBody
        cp.cpShapeFree(self.cpShape);
        cp.cpBodyFree(self.cpBody);
    }
};

const Wall = struct {
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

    fn init(space: *cp.struct_cpSpace, pos: rl.Vector2, size: rl.Vector2, color: rl.Color) !Wall {
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

    fn draw(self: Wall) void {
        // rl.drawRectangleV(self.pos, self.size, self.color);
        const offsetPos = .{ .x = self.pos.x - self.size.x / 2, .y = self.pos.y - self.size.y / 2 };
        rl.drawRectangleV(offsetPos, self.size, self.color);
    }

    fn update(_: *Wall) void {
        // const newPos = cp.cpBodyGetPosition(self.cpBody);
        // self.pos = .{ .x = @floatCast(newPos.x), .y = @floatCast(newPos.y) };
    }

    fn deinitWalls(buffer: []Wall) void {
        for (buffer) |*wall| {
            wall.deinit();
        }
    }

    fn deinit(self: *Wall) void {
        cp.cpShapeFree(self.cpShape);
    }

    fn generateWalls(buffer: []Wall, space: *cp.struct_cpSpace, width: comptime_int, height: comptime_int) !void {
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
