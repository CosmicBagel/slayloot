const std = @import("std");
const rl = @import("raylib");

const cp = @cImport({
    @cInclude("chipmunk/chipmunk.h");
});

const sl = struct {
    usingnamespace @import("components.zig");
};

pub const Player = struct {
    const movementData = struct {
        moveForce: f64,
        speedMax: f64,
        running: bool,
        runningMultiplier: f64,
        damping: f64,
    };

    centerPos: rl.Vector2,
    rect: sl.DrawRectangleComponent,
    cpBody: *cp.cpBody,
    cpShape: *cp.cpShape,
    movement: *movementData,
    allocator: std.mem.Allocator,

    // default values
    const mass = 80;
    const width = 16;
    const height = width;
    const radius = width / 2.0;
    const speedMax = 200;
    const moveForce = 12 * 1_000 * 80;
    const runningMultiplier = 2.5;
    const damping = 0.6;

    pub fn init(space: *cp.struct_cpSpace, allocator: std.mem.Allocator) !Player {
        const rect = .{
            .size = .{ .x = width, .y = height },
            .color = rl.Color.dark_green,
        };
        const pos = .{ .x = 50, .y = 50 };

        const moment = std.math.inf(f64); //infinite moment disabled rotation // cp.cpMomentForBox(mass, width, height);
        const body = cp.cpBodyNew(mass, moment) orelse return error.GenericError;
        cp.cpBodySetVelocityUpdateFunc(body, bodyUpdateVelocity);

        // save a pointer to self to the body
        const movement: *movementData = try allocator.create(movementData);
        movement.speedMax = speedMax;
        movement.moveForce = moveForce;
        movement.running = false;
        movement.runningMultiplier = runningMultiplier;
        movement.damping = damping;
        cp.cpBodySetUserData(body, movement);

        //cpSpaceAddBody returns the same pointer we pass in... idk why
        _ = cp.cpSpaceAddBody(space, body) orelse return error.GenericError;

        cp.cpBodySetPosition(body, cp.cpv(pos.x, pos.y));

        // const shape = cp.cpBoxShapeNew(body, width, height, 0) orelse return error.GenericError;
        const shape = cp.cpCircleShapeNew(body, radius, cp.cpv(0, 0)) orelse return error.GenericError;
        //cpSpaceAddShape also returns the same pointer we pass in...
        _ = cp.cpSpaceAddShape(space, shape) orelse return error.GenericError;

        return Player{
            .rect = rect,
            .centerPos = pos,
            .cpBody = body,
            .cpShape = shape,
            .movement = movement,
            .allocator = allocator,
        };
    }

    pub fn update(self: *Player) void {
        const newPos = cp.cpBodyGetPosition(self.cpBody);
        self.centerPos = .{ .x = @floatCast(newPos.x), .y = @floatCast(newPos.y) };

        var moveVec = cp.cpVect{ .x = 0, .y = 0 };
        if (rl.isKeyDown(rl.KeyboardKey.key_w)) {
            moveVec.y += 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_s)) {
            moveVec.y -= 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_d)) {
            moveVec.x += 1;
        }
        if (rl.isKeyDown(rl.KeyboardKey.key_a)) {
            moveVec.x -= 1;
        }

        self.movement.running = rl.isKeyDown(rl.KeyboardKey.key_left_shift);

        moveVec = cp.cpvnormalize(moveVec);
        moveVec = cp.cpvmult(moveVec, self.movement.moveForce);

        cp.cpBodyApplyForceAtLocalPoint(self.cpBody, moveVec, .{ .x = 0, .y = 0 });
        // cp.cpBodySetVelocity(self.cpBody, moveVec);
    }

    fn bodyUpdateVelocity(body: ?*cp.cpBody, gravity: cp.cpVect, _: cp.cpFloat, dt: cp.cpFloat) callconv(.C) void {
        // ignored input is damping

        const movement: *movementData = @ptrCast(@alignCast(cp.cpBodyGetUserData(body)));

        cp.cpBodyUpdateVelocity(body, gravity, movement.damping, dt); // 0 = max damping

        const vel = cp.cpBodyGetVelocity(body);
        cp.cpBodySetVelocity(
            body,
            cp.cpvclamp(
                vel,
                if (movement.running) movement.speedMax * movement.runningMultiplier else movement.speedMax,
            ),
        );
    }

    pub fn draw(self: Player) void {
        self.rect.draw(self.centerPos);
    }

    pub fn deinit(self: *Player) void {
        self.allocator.destroy(self.movement);

        // clean up cpShapes first then cpBody
        cp.cpShapeFree(self.cpShape);
        cp.cpBodyFree(self.cpBody);
    }
};
