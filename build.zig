const std = @import("std");


pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zglfw = b.dependency("zglfw", .{});
    const zopengl = b.dependency("zopengl", .{});

    const module = b.addModule("skore", .{
        .root_source_file = b.path("src/skore.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.linkLibrary(zglfw.artifact("glfw"));

    module.addImport("zglfw", zglfw.module("root"));
    module.addImport("zopengl", zopengl.module("root"));


    const testbed = b.addExecutable(.{
        .name = "testbed",
        .root_source_file = b.path("testbed/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    testbed.subsystem = .Windows;
    
    b.installArtifact(testbed);
    testbed.root_module.addImport("skore", module);

    @import("system_sdk").addLibraryPathsTo(testbed);

    const run_cmd = b.addRunArtifact(testbed);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);


    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/skore.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
