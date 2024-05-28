const glfw = @import("zglfw");
const opengl = @import("zopengl");

pub const Window = struct {
    internal: *glfw.Window,

    pub fn deinit(self: *Window) void {
        self.internal.destroy();
    }

    pub fn shouldClose(self: *Window) bool {
        return self.internal.shouldClose();
    }

    pub fn swapBuffers(self: *Window) void {
        self.internal.swapBuffers();
    }
};

const gl_major = 4;
const gl_minor = 0;
var gl_loaded = false;

pub fn init() !void {
    try glfw.init();

    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    glfw.swapInterval(1);
}

pub fn createWindow(width: i32, height: i32, title: [:0]const u8) !Window {

    glfw.windowHint(.maximized, 1);

    const window = Window{ .internal = try glfw.Window.create(width, height, title, null) };

    makeContextCurrent(window);

    if (!gl_loaded) {
        try opengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);
        gl_loaded = true;
    }

    return window;
}

pub fn makeContextCurrent(window: Window) void {
    glfw.makeContextCurrent(window.internal);
}

pub fn deinit() void {
    glfw.terminate();
}

pub fn pollEvents() void {
    glfw.pollEvents();
}