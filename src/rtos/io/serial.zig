const std = @import("std");
const gpio = @import("../../hardware/gpio.zig").gpio;
const aux = @import("../../hardware/aux.zig").aux;
const uart = @import("../../hardware/uart.zig");
const mbox = @import("../../hardware/mbox.zig").mbox;

const MUWriter = std.io.Writer(void, WriteError, muWrite);
const UARTWriter = std.io.Writer(void, WriteError, uartWrite);
const WriteError = error{};

/// Writer that utilizes the mini UART auxillary hardware.
const mu_writer = MUWriter{.context = {}};
/// Writer that utilizes the UART hardware.
const uart_writer = UARTWriter{.context = {}};

/// Default writer for serial streams.
pub const writer = uart_writer;
/// Default initialization function for serial stream. Must be called
/// prior to serial I/O.
pub const initSerialStreams = initUART;

/// Initialize the mini UART for communication. This will reprogram
/// GPIO pins 14 and 15. This will also clear all data in the mini
/// UART FIFO queues.
fn initMU() void {
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

/// Initialize the  UART for communication. This will reprogram GPIO
/// pins 14 and 15, set the UART clock to 4MHz, and reset UART related
/// data.
fn initUART() void {
    const uart_clock = 4000000;
    const baud = 115200;
    const brs = comptime uart.baud(baud, uart_clock);
    std.debug.assert(
        mbox.setClockSpeed(.uart, uart_clock) == uart_clock
    );
    std.debug.assert(!uart.uart.control().uart_en);
    gpio.fnSel(14, .alt0);
    gpio.fnSel(15, .alt0);
    uart.uart.baud_divisor = brs.i;
    uart.uart.fractional_baud_divisor = brs.f;
    const lc: uart.LineControl = .{
        .fifo_enable = true,
        .word_length = .ua8bit,
    };
    uart.uart.line_control = @bitCast(lc);
    const ctl: uart.Control = .{
        .uart_en = true,
    };
    uart.uart.f_control = @bitCast(ctl);
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

fn muWrite(_: void, data: []const u8) WriteError!usize {
    for (data) |b| {
        if (b == '\n')
            aux.muSendByte('\r');
        aux.muSendByte(b);
    }
    return data.len;
}

fn uartWrite(_: void, data: []const u8) WriteError!usize {
    for (data) |b| {
        if (b == '\n')
            uart.uart.sendByte('\r');
        uart.uart.sendByte(b);
    }
    return data.len;
}
