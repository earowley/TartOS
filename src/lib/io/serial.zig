const std = @import("std");
const hw = @import("hardware");
const gpio = hw.gpio.GPIO.resource;
const aux = hw.aux.aux;
const uart = hw.uart.UART.resource;
const Mailbox = hw.mbox.Mailbox;

/// Errors that can occur working with serial streams.
pub const SerialError = error {HardwareBusy};
/// Writer interface implemented with the mini UART. The easiest way
/// to get an instance of this struct is by calling `initMU`.
pub const MUWriter = std.io.Writer(void, SerialError, muWrite);
/// Writer interface implemented with the UART. The easiest way
/// to get an instance of this struct is by calling `initUART`.
pub const UARTWriter = std.io.Writer(void, SerialError, uartWrite);

const mu_writer = MUWriter{.context = {}};
const uart_writer = UARTWriter{.context = {}};
var current_writer: ?SerialStream = null;

const SerialStream = enum {
    mini_uart,
    uart,
};

/// Initialize the mini UART for communication. This will reprogram
/// GPIO pins 14 and 15. This will also clear all data in the mini
/// UART FIFO queues.
pub fn initMU() SerialError!MUWriter {
    if (current_writer) |tmp| {
        if (tmp != .mini_uart)
            return SerialError.HardwareBusy;
        return mu_writer;
    }
    const baud = 115200;
    const sys_clk = Mailbox.clockSpeed(.core);
    const bd = ((sys_clk / baud) >> 3) - 1;
    current_writer = .mini_uart;
    // Alt5 = TXD1/RXD1 on these pins.
    gpio.fnSel(14, .alt5);
    gpio.fnSel(15, .alt5);
    aux.muEnable();
    // Disable comms for further configuration.
    aux.muDisableComm();
    // Clear anything that might be in the FIFOs before configuring.
    aux.muClearFIFOs();
    aux.muSetDataSize(.mu8bit);
    aux.mu_baud = bd;
    aux.muEnableComm();
    return mu_writer;
}

/// Initialize the  UART for communication. This will reprogram GPIO
/// pins 14 and 15, set the UART clock to 4MHz, and reset UART related
/// data.
pub fn initUART() SerialError!UARTWriter {
    const uart_clock = 4000000;
    const baud = 115200;
    const brs = comptime hw.uart.baud(baud, uart_clock);
    if (current_writer) |tmp| {
        if (tmp != .uart)
            return SerialError.HardwareBusy;
        return uart_writer;
    }
    current_writer = .uart;
    std.debug.assert(
        Mailbox.setClockSpeed(.uart, uart_clock) == uart_clock
    );
    std.debug.assert(!uart.control().uart_en);
    gpio.fnSel(14, .alt0);
    gpio.fnSel(15, .alt0);
    uart.baud_divisor = brs.i;
    uart.fractional_baud_divisor = brs.f;
    const lc: hw.uart.LineControl = .{
        .fifo_enable = true,
        .word_length = .ua8bit,
    };
    uart.line_control = @bitCast(lc);
    const ctl: hw.uart.Control = .{
        .uart_en = true,
    };
    uart.f_control = @bitCast(ctl);
    return uart_writer;
}

fn muWrite(_: void, data: []const u8) SerialError!usize {
    for (data) |b| {
        if (b == '\n')
            aux.muSendByte('\r');
        aux.muSendByte(b);
    }
    return data.len;
}

fn uartWrite(_: void, data: []const u8) SerialError!usize {
    for (data) |b| {
        if (b == '\n')
            uart.sendByte('\r');
        uart.sendByte(b);
    }
    return data.len;
}
