const c = @import("constants.zig");

/// Interface directly with the timer hardware. This structure
/// is mapped to the CPU's MMIO address space.
pub const system_timer: *volatile SystemTimer = @ptrFromInt(
    c.mmio_base + 0x3000);

/// Helper structure for timer hardware.
pub const SystemTimer = extern struct {
    /// Frequency of the timer in Hz. Always running at 1MHz.
    pub const frequency = 1000000;
    const Self = *volatile @This();

    control_status: u32,
    counter_low: u32,
    counter_high: u32,
    compare: [4]u32,

    /// Get the current 64-bit counter.
    pub fn counter(self: Self) u64 {
        const rh0 = self.counter_high;
        const rl0 = self.counter_low;

        if (rh0 != self.counter_high) {
            const rh1 = self.counter_high;
            const rl1 = self.counter_low;
            return (@as(u64, rh1) << 32) | rl1;
        }

        return (@as(u64, rh0) << 32) | rl0;
    }
};
