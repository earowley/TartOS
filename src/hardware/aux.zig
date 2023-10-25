const std = @import("std");
const c = @import("constants.zig");

/// Interface directly with the auxillary hardware. This structure
/// is mapped to the CPU's MMIO address space.
pub const aux: *volatile AUX = @ptrFromInt(c.mmio_base + 0x215000);

/// Helper structure for AUX hardware.
pub const AUX = extern struct {
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
        self.enables |= 1;
    }

    /// Disable the mini UART auxillary hardware. This will disable
    /// access to the mini UART registers.
    pub fn muDisable(self: Self) void {
        self.enables &= ~@as(u32, 1);
    }

    /// Get the current interrupt status bits for MU, SPI1, and SPI2.
    pub fn interruptStatus(self: Self) InterruptStatus {
        return @bitCast(self.irq);
    }

    /// Clear the MU recv FIFO.
    pub fn muClearRecvFIFO(self: Self) void {
        self.mu_iir = 0x2;
    }

    /// Clear the MU send FIFO.
    pub fn muClearSendFIFO(self: Self) void {
        self.mu_iir = 0x4;
    }

    /// Clear both the MU send and recv FIFOs.
    pub fn muClearFIFOs(self: Self) void {
        self.mu_iir = 0x6;
    }

    /// Set the MU data size to either 7 or 8 bits.
    pub fn muSetDataSize(self: Self, size: MUDataSize) void {
        if (size == .mu7bit)
            self.mu_lcr &= ~@as(u32, 3)
        else
            self.mu_lcr |= 3;
    }

    /// Get the MU data status.
    pub fn muDataStatus(self: Self) MUDataStatus {
        return @bitCast(self.mu_lsr);
    }

    /// Disable TX and RX on the MU.
    pub fn muDisableComm(self: Self) void {
        self.mu_cntl &= ~@as(u32, 3);
    }

    /// Enable TX and RX on the MU.
    pub fn muEnableComm(self: Self) void {
        self.mu_cntl |= 3;
    }

    /// Get the current status bits of the mini UART.
    pub fn muStatus(self: Self) MUStatus {
        return @bitCast(self.mu_stat);
    }

    /// Synchronously send a byte with the mini UART.
    pub fn muSendByte(self: Self, data: u8) void {
        while (!self.muDataStatus().transmitter_empty) {}
        self.mu_io = data;
    }

    /// Synchronously receive a byte with the mini UART.
    pub fn muReceiveByte(self: Self) u8 {
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

/// AUX interrupt status (bitfield) structure.
pub const InterruptStatus = packed struct(u32) {
    mu: bool,
    spi1: bool,
    spi2: bool,
    rsvd: u29,
};

/// Available data sizes for mini UART communications.
pub const MUDataSize = enum {
    mu7bit,
    mu8bit,
};

/// MU data status (bitfield) structure.
pub const MUDataStatus = packed struct(u32) {
    data_ready: bool,
    receiver_overrun: bool,
    rsvd: u3,
    transmitter_empty: bool,
    transmitter_idle: bool,
    pad: u25,
};

/// MU status (bitfield) structure.
pub const MUStatus = packed struct(u32) {
    symbol_available: bool,
    space_available: bool,
    receiver_idle: bool,
    transmitter_idle: bool,
    receiver_overrun: bool,
    transmit_full: bool,
    rts_status: bool,
    cts_status: bool,
    transmit_empty: bool,
    transmitter_done: bool,
    rsvd0: u6,
    receive_fill: u4,
    rsvd1: u4,
    transmit_fill: u4,
    rsvd2: u4,
};
