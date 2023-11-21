const lib = @import("lib");

var stream: lib.io.serial.SerialStream = undefined;

/// Initialize the RTOS core.
pub fn initCore() void {
    stream = lib.io.serial.SerialStream.initUART() catch unreachable;
}

/// Print a string to the default serial stream.
pub fn print(s: []const u8) void {
    stream.writer().writeAll(s) catch unreachable;
}

/// Print a string to the default serial stream and ensure the string is
/// followed by a newline.
pub fn println(s: []const u8) void {
    print(s);
    if (s[s.len - 1] != '\n')
        print("\r\n");
}

/// Print a formatted string to the default serial stream.
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    stream.writer().print(fmt, args) catch unreachable;
}

/// Read a single byte from the default serial stream.
pub fn getc() u8 {
    return stream.reader().readByte() catch unreachable;
}

/// Read characters from the default serial stream until a newline is
/// encountered or `buffer` is full. To echo back the characters that
/// are read, set `echo` to **true**. This is useful for user input,
/// but not recommended for binary input.
pub fn gets(buffer: []u8, echo: bool) usize {
    const reader = stream.reader();
    const writer = stream.writer();
    var count: usize = 0;
    while (count < buffer.len) {
        const data = reader.readByte() catch unreachable;
        if (data == 0x7F or data == 0x8) {
            if (count > 0) {
                count -= 1;
                if (echo) print("\x08 \x08");
            }
            continue;
        }
        if (echo) writer.writeByte(data) catch unreachable;
        if (data == '\r') {
            if (echo) writer.writeByte('\n') catch unreachable;
            return count;
        }
        buffer[count] = data;
        count += 1;
    }
    return buffer.len;
}

/// Read bytes from the default serial stream until `buffer` is full.
pub fn read(buffer: []u8) usize {
    stream.reader().read(buffer) catch unreachable;
}
