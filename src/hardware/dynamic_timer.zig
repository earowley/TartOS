const c = @import("constants.zig");

/// Timer based on an ARM SP804. The frequency is derived from the
/// system clock, so this is not an ideal timer for generating
/// interrupts reliably on wall time. It is, however good for generating
/// interrupts with a frequency tied to the overall power state of the
/// system.
pub const DynamicTimer = extern struct {
    /// Interface directly with the timer hardware. This structure
    /// is mapped to the CPU's MMIO address space.
    pub const resource: Self = @ptrFromInt(c.mmio_base + 0xB400);
    const Self = *volatile @This();

    load: u32,
    value: u32,
    control: u32,
    irq_clear: u32,
    irq_status: u32,
    irq_masked_status: u32,
    reload: u32,
    pre_divider: u32,
    free_running_counter: u32,
};
