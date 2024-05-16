const rl = @import("raylib");
const cp = @cImport({
    @cInclude("chipmunk/chipmunk.h");
});

const sl = struct {
    usingnamespace @import("components.zig");
};

pub const Player = struct {
    centerPos: rl.Vector2,
    speed: f64,
    rect: sl.DrawRectangleComponent,
    cpBody: *cp.cpBody,
    cpShape: *cp.cpShape,

    const mass = 1;
    const width = 25;
    const height = 25;
    const radius = 0;

    pub fn init(space: *cp.struct_cpSpace) !Player {
        const rect = .{ .size = .{ .x = 25, .y = 25 }, .color = rl.Color.dark_green };
        const pos = .{ .x = 50, .y = 50 };
        const speed = 1000;

        const moment = cp.cpMomentForBox(mass, width, height);
        const body = cp.cpBodyNew(mass, moment) orelse return error.GenericError;

        //cpSpaceAddBody returns the same pointer we pass in... idk why
        _ = cp.cpSpaceAddBody(space, body) orelse return error.GenericError;
        // cp.cpBodySetDamping(body, 0); // max damp

        cp.cpBodySetPosition(body, cp.cpv(pos.x, pos.y));

        const shape = cp.cpBoxShapeNew(body, width, height, radius) orelse return error.GenericError;
        //cpSpaceAddShape also returns the same pointer we pass in...
        _ = cp.cpSpaceAddShape(space, shape) orelse return error.GenericError;

        return Player{ .rect = rect, .centerPos = pos, .speed = speed, .cpBody = body, .cpShape = shape };
    }

    pub fn update(self: *Player) void {
        const newPos = cp.cpBodyGetPosition(self.cpBody);
        self.centerPos = .{ .x = @floatCast(newPos.x), .y = @floatCast(newPos.y) };

        var moveVec = cp.cpVect{ .x = 0, .y = 0 };
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

        cp.cpBodyApplyForceAtLocalPoint(self.cpBody, moveVec, .{ .x = 0, .y = 0 });
        // cp.cpBodySetVelocity(self.cpBody, moveVec);
    }

    pub fn draw(self: Player) void {
        self.rect.draw(self.centerPos);
    }

    pub fn deinit(self: *Player) void {
        // clean up cpShapes first then cpBody
        cp.cpShapeFree(self.cpShape);
        cp.cpBodyFree(self.cpBody);
    }
};
