const std = @import("std");
const skore = @import("skore");

const App = skore.App;

pub fn main() !void {
    
    var app = App.init(std.heap.page_allocator);
    defer app.deinit();

    try app.run();

}
