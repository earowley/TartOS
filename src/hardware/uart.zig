const std = @import("std");
const c = @import("constants.zig");

/// Helper structure for UART hardware.
pub const UART = extern struct {
    /// Interface directly with the UART hardware. This structure
    /// is mapped to the CPU's MMIO address space.
    pub const resource: Self = @ptrFromInt(c.mmio_base + 0x201000);
    const Self = *volatile @This();

    data: u32,
    rsrec: u32,
    rsvd0: [4]u32,
    f_flags: u32,
    rsvd1: [2]u32,
    baud_divisor: u32,
    fractional_baud_divisor: u32,
    line_control: u32,
    f_control: u32,
    level_select: u32,
    interrupt_mask_set_clear: u32,
    raw_interrupt_status: u32,
    masked_interrupt_status: u32,
    interrupt_clear: u32,
    dma_control: u32,
    rsvd2: [13]u32,
    test_control: u32,
    integration_test_input: u32,
    integration_test_output: u32,
    test_data: u32,

    comptime {std.debug.assert(@sizeOf(UART) == 0x90);}

    /// Read the receive status register bitfield.
    pub fn receiveStatus(self: Self) ReceiveStatus {
        return @bitCast(self.rsrec);
    }

    /// Read the flags register bitfield.
    pub fn flags(self: Self) Flags {
        return @bitCast(self.f_flags);
    }

    /// Read the line control register bitfield.
    pub fn lineControl(self: Self) LineControl {
        return @bitCast(self.line_control);
    }

    /// Read the control register bitfield.
    pub fn control(self: Self) Control {
        return @bitCast(self.f_control);
    }

    /// Read the raw interrupt status bitfield.
    pub fn rawInterruptStatus(self: Self) Interrupts {
        return @bitCast(self.raw_interrupt_status);
    }

    /// Read the masked interrupt status bitfield.
    pub fn maskedInterruptStatus(self: Self) Interrupts {
        return @bitCast(self.masked_interrupt_status);
    }

    /// Read the interrupt mask bitfield.
    pub fn interruptMasks(self: Self) Interrupts {
        return @bitCast(self.interrupt_mask_set_clear);
    }

    /// Enqueue a byte on the transmit FIFO. The caller should ensure
    /// the UART is enabled and the transmit FIFO is enabled.
    pub fn sendByte(self: Self, data: u8) void {
        std.debug.assert(
            self.lineControl().fifo_enable and
            self.control().uart_en and
            self.control().transmit_en
        );
        while (self.flags().send_fifo_full) {}
        self.data = data;
    }

    /// Read a byte from the receive FIFO. The caller should ensure the
    /// UART is enabled and the receive FIFO is enabled.
    pub fn recvByte(self: Self) u8 {
        std.debug.assert(
            self.lineControl().fifo_enable and
            self.control().uart_en and
            self.control().receive_en
        );
        while (self.flags().recv_fifo_empty) {}
        const data: Data = @bitCast(self.data);
        return data.data;
    }
};

/// UART Data register bitfield.
pub const Data = packed struct(u32) {
    data: u8 = 0,
    framing_error: bool = false,
    parity_error: bool = false,
    break_error: bool = false,
    overrun_error: bool = false,
    pad: u20 = 0,
};

/// UART ReceiveStatus register bitfield.
pub const ReceiveStatus = packed struct(u32) {
    framing_error: bool = 0,
    parity_error: bool = 0,
    break_error: bool = 0,
    overrun_error: bool = 0,
    pad: u28 = 0,
};

/// UART Flags register bitfield.
pub const Flags = packed struct(u32) {
    clear_to_send: bool = false,
    rsvd0: u2 = 0,
    busy: bool = false,
    recv_fifo_empty: bool = false,
    send_fifo_full: bool = false,
    recv_fifo_full: bool = false,
    send_fifo_empty: bool = true,
    pad: u24 = 0,
};

/// Possible word lengths for UART communications.
pub const WordLength = enum(u2) {
    ua5bit,
    ua6bit,
    ua7bit,
    ua8bit,
};

/// Integer/Fractional parts of baud rate calculations. For programming
/// UART baud registers.
pub const BaudRegs = struct {
    i: u16,
    f: u6,
};

/// UART LineControl register bitfield.
pub const LineControl = packed struct(u32) {
    send_break: bool = false,
    parity_enable: bool = false,
    even_parity: bool = false,
    two_stop_bits: bool = false,
    fifo_enable: bool = false,
    word_length: WordLength = .ua5bit,
    stick_parity: bool = false,
    pad: u24 = 0,
};

/// UART Control register bitfield.
pub const Control = packed struct(u32) {
    uart_en: bool = false,
    rsvd0: u6 = 0,
    loopback_en: bool = false,
    transmit_en: bool = true,
    receive_en: bool = true,
    rsvd1: u1 = 0,
    request_to_send: bool = false,
    rsvd2: u2 = 0,
    rts_en: bool = false,
    cts_en: bool = false,
    pad: u16 = 0,
};

/// UART InterruptFIFOSelect register bitfield.
pub const InterruptFIFOSelect = packed struct(u32) {
    tx_interrupt_select: u3 = 0,
    rx_interrupt_select: u3 = 0,
    pad: u26 = 0,
};

/// UART Interrupts bitfield. Represents the layout for all
/// interrupt registers.
pub const Interrupts = packed struct(u32) {
    rsvd0: u1 = 0,
    clear_to_send: bool = false,
    rsvd1: u2 = 0,
    receive: bool = false,
    transmit: bool = false,
    receive_timeout: bool = false,
    framing_error: bool = false,
    parity_error: bool = false,
    break_error: bool = false,
    overrun_error: bool = false,
    pad: u21 = 0,
};

/// Calculate the baud rate register values given a baud `rate` and
/// the programmed UART clock frequency `uclk_freq`.
pub fn baud(rate: u32, uclk_freq: u32) BaudRegs {
    const norm = (uclk_freq << 2) / rate;
    return .{
        .i = norm >> 6,
        .f = norm & 0x3F,
    };
}
