const c = @import("constants.zig");

/// Peripheral interrupt controller.
pub const Interrupt = extern struct {
    /// Interface directly with the interrupt controller hardware. This
    /// structure is mapped to the CPU's MMIO address space.
    pub const resource: Self = @ptrFromInt(c.mmio_base + 0xB200);
    const Self = *volatile @This();

    basic_pending: u32,
    irq_pending: [2]u32,
    fiq_control: u32,
    irq_enable: [2]u32,
    basic_enable: u32,
    irq_disable: [2]u32,
    basic_disable: u32,

    /// Enable GPU peripheral interrupt `num`.
    pub fn enableIRQ(self: Self, num: u6) void {
        const idx: usize = if (num < 32) 0 else 1;
        self.irq_enable[idx] |= @as(u32, 1) << @intCast(num & 31);
    }

    /// Disable GPU peripheral interrupt `num`.
    pub fn disableIRQ(self: Self, num: u6) void {
        const idx = if (num < 32) 0 else 1;
        self.irq_disable[idx] |= @as(u32, 1) << @intCast(num & 31);
    }

    /// Check whether GPU peripheral interrupt `num` is asserted.
    pub fn checkAssertedIRQ(self: Self, num: u6) bool {
        const idx = if (num < 32) 0 else 1;
        return (self.irq_pending[idx] & 
            @as(u32, 1) << @intCast(num & 31)) != 0;
    }

    /// Get the asserted status for basic interrupts.
    pub fn basicPending(self: Self) BasicPending {
        return @bitCast(self.basic_pending);
    }

    /// Get the FIQ control register. This can be used to enable FIQ
    /// for one of the GPU peripheral interrupts (0-63). Numbers 64-71
    /// can be used to enable FIQ for basic interrupt sources.
    pub fn fiqControl(self: Self) FIQControl {
        return @bitCast(self.fiq_control);
    }

    /// Get the basic enable register.
    pub fn basicEnable(self: Self) BasicEnable {
        return @bitCast(self.basic_enable);
    }
};

/// Interrupt controller basic pending register bitfield.
pub const BasicPending = packed struct(u32) {
    // Is this dyn, cntp, or local?
    arm_timer: bool = false,
    arm_mailbox: bool = false,
    arm_doorbell0: bool = false,
    arm_doorbell1: bool = false,
    gpu_halt0: bool = false,
    gpu_halt1: bool = false,
    illegal_access0: bool = false,
    illegal_access1: bool = false,
    pending0: bool = false,
    pending1: bool = false,
    gpu7: bool = false,
    gpu9: bool = false,
    gpu10: bool = false,
    gpu18: bool = false,
    gpu19: bool = false,
    gpu53: bool = false,
    gpu54: bool = false,
    gpu55: bool = false,
    gpu56: bool = false,
    gpu57: bool = false,
    gpu62: bool = false,
    pad: u11 = 0,
};

/// Interrupt controller FIQ control register bitfield.
pub const FIQControl = packed struct(u32) {
    source: u7 = 0,
    en: bool = false,
    pad: u24 = 0,
};

/// Interrupt controller basic enable register bitfield.
pub const BasicEnable = packed struct(u32) {
    arm_timer: bool = false,
    arm_mailbox: bool = false,
    arm_doorbell0: bool = false,
    arm_doorbell1: bool = false,
    gpu_halt0: bool = false,
    gpu_halt1: bool = false,
    illegal_access0: bool = false,
    illegal_access1: bool = false,
    pad: u24 = 0,
};
