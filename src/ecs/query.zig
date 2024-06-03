
pub fn QueryIter(comptime Types: anytype) type {
    return struct {
        const This = @This();

        pub fn next(_: *This) ?QueryIter(Types) {
            return null;
        }

        pub fn get(_: This, comptime T: type) *const T {}

        pub fn getMut(_: This, comptime T: type) *T {}
    };
}

pub fn Query(comptime T: anytype) type {
    return struct {
        const This = @This();


        pub fn iter(_: *This) ?QueryIter(T) {
            return null;
        }

    };
}
