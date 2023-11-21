/// Generic iterator interface.
pub fn Iterator(
    comptime NextType: type,
    comptime Context: type,
    comptime NextFn: *const fn(cxt: *Context) ?NextType
) type {
    return struct {
        const Self = @This();

        cxt: Context,

        /// Get the next item in this iterator, or null if the iterator
        /// is exhausted.
        pub fn next(self: *Self) ?NextType {
            return NextFn(&self.cxt);
        }
    };
}
