const std = @import("std");
const skore = @import("skore");

const App = skore.App;
const Registry = skore.Registry;
const World = skore.World;

const TestComponent = struct {
    x : u32,
    y : u32
};

const AnotherComp = struct {
    x : u32,
    y : u32
};

pub fn main() !void {
    var registry = Registry.init(std.heap.page_allocator);
    defer registry.deinit();

    registry.add(TestComponent);
    registry.add(AnotherComp);


    var world = World.init(&registry, std.heap.page_allocator);
    defer world.deinit();

    var app = try App.init(&registry,  std.heap.page_allocator);
    defer app.deinit();


    _ = world.spawn(.{
        TestComponent{
            .x = 10,
            .y = 10
        },
        AnotherComp {
            .x = 20,
            .y = 20
        }
    });

    _ = world.spawn(.{
        TestComponent{
            .x = 10,
            .y = 10
        },
        AnotherComp {
            .x = 20,
            .y = 20
        }
    });



    try app.run();
}
