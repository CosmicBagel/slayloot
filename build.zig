const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "dungeonhustle",
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    // b.installArtifact(lib);

    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raylib_math = raylib_dep.module("raylib-math"); // raymath module
    const rlgl = raylib_dep.module("rlgl"); // rlgl module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const cpDep = b.dependency("chipmunk", .{});

    const cpLib = b.addStaticLibrary(.{
        .name = "chipmunk",
        .target = target,
        .optimize = optimize,
    });

    const c_flags_default = &.{
        "-std=gnu99",
        // alright SO, chipmunk heavily relies on infinite float values
        // if you use these optimization flags, shit gets weird, do not recommend
        // "-ffast-math", (implies -ffinite-math-only)
        // "-ffinite-math-only",
        // see https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#index-ffast-math
        "-Wall",
    };

    // tell chipmunk to use floats, so we're not constantly swapping between
    // f32 and f64 (raylib only supports f32)
    // cpLib.root_module.addCMacro("CP_USE_DOUBLES", "0");

    const c_flags_nondebug = &.{
        "-DNDEBUG",
    };

    const c_flags: []const []const u8 = if (optimize != .Debug)
        (std.mem.concat(b.allocator, []const u8, &.{ c_flags_default, c_flags_nondebug }) catch @panic("OOM"))
    else
        c_flags_default;

    cpLib.addCSourceFiles(.{
        .root = cpDep.path("."),
        .files = &.{
            "src/chipmunk.c",
            "src/cpArbiter.c",
            "src/cpArray.c",
            "src/cpBBTree.c",
            "src/cpBody.c",
            "src/cpCollision.c",
            "src/cpConstraint.c",
            "src/cpDampedRotarySpring.c",
            "src/cpDampedSpring.c",
            "src/cpGearJoint.c",
            "src/cpGrooveJoint.c",
            "src/cpHashSet.c",
            "src/cpHastySpace.c",
            "src/cpMarch.c",
            "src/cpPinJoint.c",
            "src/cpPivotJoint.c",
            "src/cpPolyShape.c",
            "src/cpPolyline.c",
            "src/cpRatchetJoint.c",
            "src/cpRobust.c",
            "src/cpRotaryLimitJoint.c",
            "src/cpShape.c",
            "src/cpSimpleMotor.c",
            "src/cpSlideJoint.c",
            "src/cpSpace.c",
            "src/cpSpaceComponent.c",
            "src/cpSpaceDebug.c",
            "src/cpSpaceHash.c",
            "src/cpSpaceQuery.c",
            "src/cpSpaceStep.c",
            "src/cpSpatialIndex.c",
            "src/cpSweep1D.c",
        },
        .flags = c_flags,
    });

    cpLib.addIncludePath(cpDep.path("include"));
    cpLib.installHeadersDirectory(cpDep.path("include/chipmunk"), "chipmunk", .{});
    cpLib.linkLibC();

    b.installArtifact(cpLib);

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibrary(cpLib);
    // when zig is generating bindings for chipmunk, it needs to have this
    // define to use floats (disable use of doubles)
    // exe.root_module.addCMacro("CP_USE_DOUBLES", "0");
    exe.linkLibrary(raylib_artifact);
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raylib-math", raylib_math);
    exe.root_module.addImport("rlgl", rlgl);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const lib_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    //
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);
}
