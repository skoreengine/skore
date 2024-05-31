const std = @import("std");
const Registry = @import("registry.zig").Registry;

const glfw = @import("zglfw");
const opengl = @import("zopengl");


const gl_major = 4;
const gl_minor = 0;

pub const App = struct {
    allocator : std.mem.Allocator,
    registry : *Registry,
    running : bool,
    window : *glfw.Window,

    pub fn init(registry :* Registry, allocator : std.mem.Allocator) !App {

        try glfw.init();

        glfw.windowHintTyped(.context_version_major, gl_major);
        glfw.windowHintTyped(.context_version_minor, gl_minor);
        glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
        glfw.windowHintTyped(.opengl_forward_compat, true);
        glfw.windowHintTyped(.client_api, .opengl_api);
        glfw.windowHintTyped(.doublebuffer, true);
        glfw.swapInterval(1);
        glfw.windowHint(.maximized, 1);

        const window = try glfw.Window.create(800, 600, "Skore Engine", null);

        glfw.makeContextCurrent(window);

        try opengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

        return .{
            .allocator = allocator,
            .registry = registry,
            .running = true,
            .window = window
        };
    }

    pub fn run(self: *App) !void {
        while (self.running) {

            glfw.pollEvents();

            if (self.window.shouldClose()) {
                self.running = false;
            }

            opengl.bindings.clearBufferfv(opengl.bindings.COLOR, 0, &[_]f32{ 0.392, 0.584, 0.929, 1.0});

            self.window.swapBuffers();
        }
    }

    pub fn shutdown(self: *App) void {
        self.running = false;
    }

    pub fn deinit(_ :*App) void {
        glfw.terminate();
    }
};
