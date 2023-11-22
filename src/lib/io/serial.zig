const std = @import("std");
const hw = @import("hardware");
const gpio = hw.gpio.GPIO.resource;
const aux = hw.aux.aux;
const uart = hw.uart.UART.resource;
const Mailbox = hw.mbox.Mailbox;

/// Errors that can occur working with serial streams.
pub const SerialError = error {HardwareBusy, BadClock};
/// Generic serial writer interface.
pub const SerialWriter = std.io.Writer(void, SerialError, write);
/// Generic serial reader interface.
pub const SerialReader = std.io.Reader(void, SerialError, read);

const SerialStreamSource = enum {
    mini_uart,
    uart,
};

pub const SerialStream = struct {
    var current_stream: ?SerialStreamSource = null;
    var writeFn: *const fn([]const u8) usize = undefined;
    var readFn: *const fn([]u8) usize = undefined;

    /// Initialize the mini UART for communication. This will reprogram
    /// GPIO pins 14 and 15. This will also clear all data in the mini
    /// UART FIFO queues.
    pub fn initMU() SerialError!SerialStream {
        if (current_stream) |tmp| {
            if (tmp != .mini_uart)
                return SerialError.HardwareBusy;
            return SerialStream{};
        }
        const baud = 115200;
        const sys_clk = Mailbox.clockSpeed(.system);
        const bd = ((sys_clk / baud) >> 3) - 1;
        current_stream = .mini_uart;
        writeFn = muWrite;
        readFn = muRead;
        if (aux.enables().mu)
            aux.muDisable();
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
        return SerialStream{};
    }

    /// Initialize the  UART for communication. This will reprogram
    /// GPIO pins 14 and 15, set the UART clock to 4MHz, and reset UART
    /// related data.
    pub fn initUART() SerialError!SerialStream {
        const uart_clock = 4000000;
        const baud = 115200;
        const brs = comptime hw.uart.baud(baud, uart_clock);
        if (current_stream) |tmp| {
            if (tmp != .uart)
                return SerialError.HardwareBusy;
            return SerialStream{};
        }
        current_stream = .uart;
        writeFn = uartWrite;
        readFn = uartRead;
        if (Mailbox.setClockSpeed(.uart, uart_clock) != uart_clock)
            return SerialError.BadClock;
        if (uart.control().uart_en)
            uart.disable();
        gpio.fnSel(14, .alt0);
        gpio.fnSel(15, .alt0);
        uart.baud_divisor = brs.i;
        uart.fractional_baud_divisor = brs.f;
        const lc: hw.uart.LineControl = .{
            .fifo_enable = true,
            .word_length = .ua8bit,
        };
        uart.line_control = @bitCast(lc);
        uart.enable();
        return SerialStream{};
    }

    /// Gets a writer interface for this serial stream.
    pub fn writer(_: SerialStream) SerialWriter {
        return .{.context = {}};
    }

    /// Gets a reader interface for this serial stream.
    pub fn reader(_: SerialStream) SerialReader {
        return .{.context = {}};
    }
};

fn write(_: void, data: []const u8) SerialError!usize {
    return SerialStream.writeFn(data);
}

fn read(_: void, buffer: []u8) SerialError!usize {
    return SerialStream.readFn(buffer);
}

fn muWrite(data: []const u8) usize {
    for (data) |b| {
        if (b == '\n')
            aux.muSendByte('\r');
        aux.muSendByte(b);
    }
    return data.len;
}

fn muRead(buffer: []u8) usize {
    for (buffer) |*b| b.* = aux.muReceiveByte();
    return buffer.len;
}

fn uartWrite(data: []const u8) usize {
    for (data) |b| {
        if (b == '\n')
            uart.sendByte('\r');
        uart.sendByte(b);
    }
    return data.len;
}

fn uartRead(buffer: []u8) usize {
    for (buffer) |*b| b.* = uart.recvByte();
    return buffer.len;
}
