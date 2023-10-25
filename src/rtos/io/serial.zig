const std = @import("std");
const gpio = @import("../../hardware/gpio.zig").gpio;
const aux = @import("../../hardware/aux.zig").aux;

const Writer = std.io.Writer(void, WriteError, muWrite);
const WriteError = error{};

/// Writer that utilizes the mini UART auxillary.
pub const writer = Writer{.context = {}};

/// Initialize the mini UART for communication. This will reprogram
/// GPIO pins 14 and 15. This will also clear all data in the mini
/// UART FIFO queues.
pub fn initMU() void {
    // Alt5 = TXD1/RXD1 on these pins.
    gpio.fnSel(14, .alt5);
    gpio.fnSel(15, .alt5);
    aux.muEnable();
    // Disable comms for further configuration.
    aux.muDisableComm();
    // Clear anything that might be in the FIFOs before configuring.
    aux.muClearFIFOs();
    aux.muSetDataSize(.mu8bit);
    aux.mu_baud = 270;
    aux.muEnableComm();
}

/// Print a string using the mini UART.
pub fn print(s: []const u8) void {
    writer.writeAll(s) catch unreachable;
}

/// Print a string using the mini UART and ensure the string is
/// followed by a newline.
pub fn println(s: []const u8) void {
    print(s);
    if (s[s.len - 1] != '\n')
        print("\r\n");
}

/// Print a formatted string using the mini UART.
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    writer.print(fmt, args) catch unreachable;
}

fn muWrite(_: void, data: []const u8) WriteError!usize {
    for (data) |b| {
        if (b == '\n')
            aux.muSendByte('\r');
        aux.muSendByte(b);
    }
    return data.len;
}
