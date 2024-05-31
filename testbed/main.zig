const std = @import("std");
const skore = @import("skore");

const App = skore.App;
const Registry = skore.Registry;

pub fn main() !void {
    var registry = Registry.init(std.heap.page_allocator);
    defer registry.deinit();

    var app = try App.init(&registry,  std.heap.page_allocator);
    defer app.deinit();
    try app.run();
}
