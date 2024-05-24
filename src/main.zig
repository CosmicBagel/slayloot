// dungeon - wolf den - a large burrow, three rooms, wolfs have been attacking
//   the village, normally the wolves keep to themselves
// enemy - wolf - runs lines perpendicular to player's position, then runs in
//   for attacks, melee attacks
// enemy - wolf (iced) - like wolf, but is immune to damage until ice armour is
//   destroyed
// enemy - human skeleton - walks in straight lines (up down left right), tries
//   to pick directions away from player if the player gets to close avoid
//   melee attacks, moves slowly (he's got old rickety bones), casts firebolt at
//   player, can enrage and fear low intellect creatures, has a necromancer's
//   marking on its skull, it glows faintly
// weapon - walking stick - shoves and stuns enemies, does small amount of damage
// weapon - rusty sword - can kill a wolf in 2 or 3 hits, but does no knockback
//   or stun
// weapon - torch - normally does very little damage, but can break ice armour
//   quickly (may also light bats on fire)
// mechanic - dodge roll - roll in direction of movement, initial frames of the
//   roll are invulnerable
// mechanic - target lock-on - allows player to strafe around target and attack
// mechanic - weapon swapping - use keys 1-3 to change weapons, weapon swapping
//   interrupts attacks
// mechanic - player knockback on damage taken - use keys 1-3 to change
//   weapons, weapon swapping interrupts attacks
// mechanic - killing an enemy results in health regain for the player
// mechanic - can not progress to next room till all enemies are killed in
//   current room
// system - walking between rooms
// system - rooms - all rooms are visually the same, just different enemies,
//   doors on the left and right, walls all around, left door opens when all
//   enemies are dead, text on screen indicates which room you're in (to help
//   with the visual sameness)
// system - damage (with damage type), knockback, stun
// system - notify on kill (do not try to build a full event system lol)

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
    var windowWidth: i32 = 1280;
    var windowHeight: i32 = 720;

    // nes PAL screen had 256x240 (NTSC was smaller), taking this and widening
    // it by increments of 8 to get it closer to a 16:9 ratio
    const renderWidth = 424 + 3; // 53 8x8 tiles + 3 pixels to make it fit 16:9 nicely
    const renderHeight = 240; // 30 8x8 tiles
    // reserve two tiles at the top for some UI stuff (health, weapon)
    // so rooms can be 53 tiles wide and 28 tiles tall
    // 26 x 14 16x16 tiles + 1 8x8 tile horizontally

    rl.initWindow(windowWidth, windowHeight, "slayloot");
    rl.setWindowState(rl.ConfigFlags.flag_window_resizable);
    rl.setWindowMinSize(renderWidth, renderHeight);
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // scene camera
    var camera: rl.Camera2D = rl.Camera2D{
        .target = .{ .x = renderWidth / -2, .y = renderHeight / -2 },
        .offset = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1,
    };

    // render target texture
    const renderTarget: rl.RenderTexture2D = rl.loadRenderTexture(renderWidth, renderHeight);

    // init physics
    const space = cp.cpSpaceNew() orelse return error.GenericError;
    defer cp.cpSpaceFree(space);
    const gravity = cp.cpv(0, 0);
    cp.cpSpaceSetGravity(space, gravity);
    cp.cpSpaceSetDamping(space, 1); // min damp

    // init game objects
    var playerDataBuffer: [1000]u8 = undefined;
    var playerDataFba = std.heap.FixedBufferAllocator.init(&playerDataBuffer);
    var p = try sl.Player.init(space, playerDataFba.allocator());
    defer p.deinit();

    var walls: [42]sl.Wall = undefined;
    try sl.Wall.generateWalls(&walls, space, 16, 8);
    defer sl.Wall.deinitWalls(&walls);

    // game loop
    while (!rl.windowShouldClose() and rl.isKeyUp(rl.KeyboardKey.key_q)) {
        if (rl.isKeyPressed(rl.KeyboardKey.key_f11)) {
            rl.toggleBorderlessWindowed();
        }
        if (rl.isWindowResized()) {
            windowWidth = rl.getScreenWidth();
            windowHeight = rl.getScreenHeight();
        }

        // physics tick here
        cp.cpSpaceStep(space, rl.getFrameTime());

        // update game objects
        p.update();
        for (&walls) |*wall| {
            wall.update();
        }

        camera.target.x = p.centerPos.x - (renderWidth / 2);
        camera.target.y = -p.centerPos.y - (renderHeight / 2);

        // draw everything
        {
            {
                // render to the texture
                rl.beginTextureMode(renderTarget);
                defer rl.endTextureMode();

                // render what camera sees
                rl.beginMode2D(camera);
                defer rl.endMode2D();

                rl.clearBackground(rl.Color.white);

                p.draw();

                for (walls) |wall| {
                    wall.draw();
                }
            }

            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.black);
            const srcRect: rl.Rectangle = rl.Rectangle.init(0, 0, renderWidth, -renderHeight);

            // preserve aspect ratio of render
            const windowWidthF32 = @as(f32, @floatFromInt(windowWidth));
            const windowHeightF32 = @as(f32, @floatFromInt(windowHeight));
            const horzScale = windowHeightF32 / renderHeight;
            const vertScale = windowWidthF32 / renderWidth;
            // use smaller scale (otherwise some of the render would go outside the window)
            const scale = if (horzScale > vertScale) vertScale else horzScale;
            const destWidth = renderWidth * scale;
            const destHeight = renderHeight * scale;
            const destRect: rl.Rectangle = rl.Rectangle.init(
                (windowWidthF32 - destWidth) / 2,
                (windowHeightF32 - destHeight) / 2,
                destWidth,
                destHeight,
            );
            const originVec: rl.Vector2 = rl.Vector2.init(0, 0);
            rl.drawTexturePro(renderTarget.texture, srcRect, destRect, originVec, 0, rl.Color.white);

            // draw ui and screen space stuff
            rl.drawText("dungeon time", 190, 200, 20, rl.Color.light_gray);
        }
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
