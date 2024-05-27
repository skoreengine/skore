const std = @import("std");
const glfw = @import("zglfw");
const opengl = @import("zopengl");

pub fn main() !void {
    std.debug.print("Hello, skore", .{});
    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(600, 600, "Skore Engine", null);
    defer window.destroy();

    glfw.makeContextCurrent(window);

    try opengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    const gl = opengl.bindings;

    glfw.swapInterval(1);

    while (!window.shouldClose()) {
        glfw.pollEvents();

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.392, 0.584, 0.929, 1.0 });

        window.swapBuffers();
    }

}

