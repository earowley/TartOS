const std = @import("std");
const c = @import("constants.zig");

/// Helper structure for AUX hardware.
pub const AUX = extern struct {
    /// Interface directly with the auxillary hardware. This structure
    /// is mapped to the CPU's MMIO address space.
    pub const resource: Self = @ptrFromInt(c.mmio_base + 0x215000);
    const Self = *volatile @This();

    irq: u32,
    enables: u32,
    rsvd0: [14]u32,
    mu_io: u32,
    mu_ier: u32,
    mu_iir: u32,
    mu_lcr: u32,
    mu_mcr: u32,
    mu_lsr: u32,
    mu_msr: u32,
    mu_scratch: u32,
    mu_cntl: u32,
    mu_stat: u32,
    mu_baud: u32,
    rsvd1: [5]u32,
    spi: [2]SPIRegSet,

    comptime {std.debug.assert(@sizeOf(AUX) == 0x100);}

    /// Enable the mini UART auxillary hardware. This should be done
    /// after setting up the required GPIO pins. This must be done
    /// before any other mini UART operations, as it enables access
    /// to the registers.
    pub fn muEnable(self: Self) void {
        var tmp: Enables = @bitCast(self.enables);
        tmp.mu = true;
        self.enables = @bitCast(tmp);
    }

    /// Disable the mini UART auxillary hardware. This will disable
    /// access to the mini UART registers.
    pub fn muDisable(self: Self) void {
        var tmp: Enables = @bitCast(self.enables);
        tmp.mu = false;
        self.enables = @bitCast(tmp);
    }

    /// Get the current interrupt status bits for MU, SPI1, and SPI2.
    pub fn interruptStatus(self: Self) InterruptStatus {
        return @bitCast(self.irq);
    }

    /// Clear the MU recv FIFO.
    pub fn muClearRecvFIFO(self: Self) void {
        var tmp = std.mem.zeroes(MUInterruptStatus);
        tmp.control_status = .clear_receive_fifo;
        self.mu_iir = @bitCast(tmp);
    }

    /// Clear the MU send FIFO.
    pub fn muClearSendFIFO(self: Self) void {
        var tmp = std.mem.zeroes(MUInterruptStatus);
        tmp.control_status = .clear_send_fifo;
        self.mu_iir = @bitCast(tmp);
    }

    /// Clear both the MU send and recv FIFOs.
    pub fn muClearFIFOs(self: Self) void {
        var tmp = std.mem.zeroes(MUInterruptStatus);
        tmp.control_status = .clear_all_fifos;
        self.mu_iir = @bitCast(tmp);
    }

    /// Set the MU data size to either 7 or 8 bits.
    pub fn muSetDataSize(self: Self, size: MUDataSize) void {
        var tmp: MULineDataFormat = @bitCast(self.mu_lcr);
        tmp.data_size = size;
        self.mu_lcr = @bitCast(tmp);
    }

    /// Get the MU data status.
    pub fn muDataStatus(self: Self) MUDataStatus {
        return @bitCast(self.mu_lsr);
    }

    /// Read the MU control status.
    pub fn muControl(self: Self) MUControl {
        return @bitCast(self.mu_cntl);
    }

    /// Disable TX and RX on the MU.
    pub fn muDisableComm(self: Self) void {
        var tmp = self.muControl();
        tmp.receive_enable = false;
        tmp.transmit_enable = false;
        self.mu_cntl = @bitCast(tmp);
    }

    /// Enable TX and RX on the MU.
    pub fn muEnableComm(self: Self) void {
        var tmp = self.muControl();
        tmp.receive_enable = true;
        tmp.transmit_enable = true;
        self.mu_cntl = @bitCast(tmp);
    }

    /// Get the current status bits of the mini UART.
    pub fn muStatus(self: Self) MUStatus {
        return @bitCast(self.mu_stat);
    }

    /// Synchronously send a byte with the mini UART. The caller should
    /// ensure the mini UART is enabled, TX is enabled, and GPIO pins
    /// are programmed correctly.
    pub fn muSendByte(self: Self, data: u8) void {
        std.debug.assert(
            self.enables().mu and
            self.muControl().transmit_enable
        );
        while (!self.muDataStatus().transmitter_empty) {}
        self.mu_io = data;
    }

    /// Synchronously receive a byte with the mini UART. The caller
    /// should ensure the mini UART is enabled, RX is enabled, and GPIO
    /// pins are programmed correctly.
    pub fn muReceiveByte(self: Self) u8 {
        std.debug.assert(
            self.enables().mu and
            self.muControl().receive_enable
        );
        while (!self.muDataStatus().data_ready) {}
        return @intCast(self.mu_io & 0xFF);
    }
};

/// Set of registers to facilitate packing the AUX structure.
pub const SPIRegSet = extern struct {
    cntl0: u32,
    cntl1: u32,
    stat: u32,
    rsvd0: u32,
    io: u32,
    peek: u32,
    rsvd1: [10]u32,
};

/// AUX interrupt status register bitfield.
pub const InterruptStatus = packed struct(u32) {
    mu: bool = false,
    spi1: bool = false,
    spi2: bool = false,
    rsvd: u29 = 0,
};

/// AUX enable register bitfield.
pub const Enables = packed struct(u32) {
    mu: bool = false,
    spi1: bool = false,
    spi2: bool = false,
    pad: u29 = 0,
};

/// AUX MU I/O register bitfield.
pub const MUInputOutput = packed struct(u32) {
    data: u8 = 0,
    pad: u24 = 0,
};

/// AUX MU interrupt enable register bitfield.
pub const MUInterruptEnable = packed struct(u32) {
    transmit: bool = false,
    receive: bool = false,
    pad: u30 = 0,
};

/// R/W values for MUInterruptStatus.control_status.
pub const InterruptControlStatus = enum(u2) {
    // Status values:
    no_interrupts = 0,
    transmit_empty = 1,
    receiver_valid = 2,
    invalid = 3,

    // Control values:
    clear_receive_fifo = 1,
    clear_transmit_fifo = 2,
    clear_all_fifos = 3,
};

/// AUX MU interrupt status register bitfield.
pub const MUInterruptStatus = packed struct(u32) {
    pending: bool = true,
    control_status: InterruptControlStatus = .no_interrupts,
    rsvd0: u3 = 0,
    fifo_enables: u2 = 3,
    pad: u24 = 0,
};

/// Available data sizes for mini UART communications.
pub const MUDataSize = enum(u1) {
    mu7bit,
    mu8bit,
};

/// AUX MU line data format register bitfield.
pub const MULineDataFormat = packed struct(u32) {
    data_size: MUDataSize = .mu7bit,
    rsvd0: u5 = 0,
    force_tx_low: bool = false,
    baud_access: bool = false,
    pad: u24 = 0,
};

/// AUX MU modem signal register bitfield.
pub const MUModemSignal = packed struct(u32) {
    rsvd0: u1 = 0,
    rts: bool = false,
    pad: u30 = 0,
};

/// AUX MU data status register bitfield.
pub const MUDataStatus = packed struct(u32) {
    data_ready: bool = false,
    receiver_overrun: bool = false,
    rsvd: u3 = 0,
    transmitter_empty: bool = false,
    transmitter_idle: bool = true,
    pad: u25 = 0,
};

/// AUX MU modem status register bitfield.
pub const MUModemStatus = packed struct(u32) {
    rsvd0: u4 = 0,
    not_cts: bool = true,
    pad: u27 = 0,
};

/// AUX MU control register bitfield.
pub const MUControl = packed struct(u32) {
    receive_enable: bool = true,
    transmit_enable: bool = true,
    rx_auto_enable: bool = false,
    tx_auto_enable: bool = false,
    auto_flow_level: u2 = 0,
    rts_assert: bool = false,
    cts_assert: bool = false,
};

/// AUX MU status register bitfield.
pub const MUStatus = packed struct(u32) {
    symbol_available: bool = false,
    space_available: bool = false,
    receiver_idle: bool = true,
    transmitter_idle: bool = true,
    receiver_overrun: bool = false,
    transmit_full: bool = false,
    rts_status: bool = false,
    cts_status: bool = false,
    transmit_empty: bool = true,
    transmitter_done: bool = true,
    rsvd0: u6 = 0,
    receive_fill: u4 = 0,
    rsvd1: u4 = 0,
    transmit_fill: u4 = 0,
    rsvd2: u4 = 0,
};

/// AUX MU baudrate register bitfield.
pub const MUBaud = packed struct(u32) {
    baudrate: u16 = 0,
    pad: u16 = 0,
};
