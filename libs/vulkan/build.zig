const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    var m = b.addModule("vulkan", .{
        .root_source_file = b.path("src/vulkan.zig"),
        .target = target,
        .optimize = optimize,
    });

    m.addCMacro("VK_NO_PROTOTYPES", "1");
    m.addIncludePath(b.path("src"));

    m.link_libcpp = true;
    m.addCSourceFile(.{ .file = b.path("src/vk_mem_alloc.cpp") });
    m.addCSourceFile(.{ .file = b.path("src/volk.c") });
}
