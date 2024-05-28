const math = @import("../core/math.zig");
const opengl = @import("zopengl");


pub fn clearBuffer(color : math.Vec4) void {
  opengl.bindings.clearBufferfv(opengl.bindings.COLOR, 0, &[_]f32{ color.x, color.y, color.z, color.w});
}
