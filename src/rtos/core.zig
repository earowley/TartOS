const lib = @import("lib");

var writer: lib.io.serial.UARTWriter = undefined;

/// Initialize the RTOS core.
pub fn initCore() void {
    writer = lib.io.serial.initUART() catch unreachable;
}

/// Print a string using the default writer.
pub fn print(s: []const u8) void {
    writer.writeAll(s) catch unreachable;
}

/// Print a string using the default writer and ensure the string is
/// followed by a newline.
pub fn println(s: []const u8) void {
    print(s);
    if (s[s.len - 1] != '\n')
        print("\r\n");
}

/// Print a formatted string using the default writer.
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    writer.print(fmt, args) catch unreachable;
}
