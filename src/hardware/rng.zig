const std = @import("std");
const c = @import("constants.zig");

/// Interface directly with the RNG hardware. This structure
/// is mapped to the CPU's MMIO address space.
pub const rng: *volatile RNG = @ptrFromInt(c.mmio_base + 0x104000);

/// Helper structure for RNG hardware.
pub const RNG = extern struct {
    const Self = *volatile @This();
    var initialized = false;

    control: u32,
    status: u32,
    data: u32,
    unused: u32,
    interrupt_mask: u32,

    /// Initialize the RNG hardware.
    pub fn init(self: Self) void {
        std.debug.assert(!initialized);
        self.status = 0x40000;
        self.control |= 1;
        initialized = true;
    }

    /// Waits for hardware to generate a random number and returns it.
    pub fn rand(self: Self) u32 {
        std.debug.assert(initialized);
        while ((self.status >> 24) == 0) {}
        return self.data;
    }
};
