const lib = @import("lib");

var stream: lib.io.serial.SerialStream = undefined;

/// Initialize the RTOS core.
pub fn initCore() void {
    stream = lib.io.serial.SerialStream.initUART() catch unreachable;
}

/// Print a string using the default writer.
pub fn print(s: []const u8) void {
    stream.writer().writeAll(s) catch unreachable;
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
    stream.writer().print(fmt, args) catch unreachable;
}

/// Reads characters until a newline is encountered, or until `buffer`
/// is full.
pub fn gets(buffer: []u8) usize {
    const reader = stream.reader();
    for (buffer, 0..) |*b, n| {
        const data = reader.readByte() catch unreachable;
        b.* = data;
        if (data == '\r') return n;
    }
    return buffer.len;
}

/// Reads bytes from serial input until `buffer` is full.
pub fn read(buffer: []u8) usize {
    stream.reader().read(buffer) catch unreachable;
}
