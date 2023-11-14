/// Peripheral hardware that drives the ARM core cluster.
///
/// # Terminology:
/// * **timer64** refers to the timer that is fed to each ARM core and
/// drives each core's timer counters.
pub const Peripherals = extern struct {
    pub const resource: Self = @ptrFromInt(0x40000000);
    const Self = *volatile @This();

    core_timer_control: u32,
    rsvd0: u32,
    core_timer_prescaler: u32,
    gpu_interrupt_route: u32,
    performance_monitor_route_set: u32,
    performance_monitor_route_clear: u32,
    rsvd1: u32,
    core_timer_lsb: u32,
    core_timer_msb: u32,
    local_timer_interrupt_route: u32,
    rsvd2: u32,
    axi_counters: u32,
    axi_irq: u32,
    local_timer_control_status: u32,
    local_timer_write_flags: u32,
    rsvd3: u32,
    core_timers_interrupt_control: [4]u32,
    core_mailbox_interrupt_control: [4]u32,
    core_irq_source: [4]u32,
    core_fiq_source: [4]u32,
    core_mailbox_write_set: [4][4]u32,
    core_mailbox_write_clear: [4][4]u32,

    /// Get the counter value of the 64-bit timer.
    pub fn timer64Counter(self: Self) u64 {
        const l: u64 = self.core_timer_lsb;
        const h: u64 = self.core_timer_msb;
        return l | (h << 32);
    }
};

/// Wait for the ARM CPU to complete at least `n` cycles. The amount
/// of wall time taken in this function is dependent on the clock
/// speed of the CPU.
pub fn waitCycles(n: usize) void {
    for (0..n) |_| {
        asm volatile("nop");
    }
}

/// Read a register named `reg` using the **mrs** instruction.
pub fn readReg(comptime reg: []const u8) usize {
    return asm volatile(
        "mrs %[reg], " ++ reg
        : [reg] "=r" (-> usize)
    );
    
}

/// Write a register named `reg` with the value `val` using the **msr**
/// instruction.
pub fn writeReg(comptime reg: []const u8, val: usize) void {
    asm volatile(
        "msr " ++ reg ++ ", %[reg]"
        :
        : [reg] "r" (val)
    );
}

/// Returns the current ARM counter frequency. This register is
/// not interpreted by hardware, and is set by firmware at boot.
/// Its only purpose is to communicate the set counter frequency to
/// the kernel/hypervisor. Documentation seems to suggest this frequency
/// is derived from the 64-bit timer provided in the ARM-local
/// peripherals.
pub fn cntfrq_el0() usize {
    return readReg("cntfrq_el0");
}

/// Returns the current ARM physical counter value. On boot, this
/// counter should increment at the frequency from CNTFRQ_EL0.
pub fn cntpct_el0() usize {
    return readReg("cntpct_el0");
}

/// Returns the ARM physical counter control register value. Contains
/// bits for timer enable, interrupt mask, and interrupt status. Note:
/// the counter is always enabled, this register only enables the timer
/// and its interrupts.
pub fn cntp_ctl_el0() usize {
    return readReg("cntp_ctl_el0");
}

/// Reads the ARM physical counter timer register. This value counts
/// down and represents the amount of ticks until a timer interrupt.
/// If the result is negative, it represents the number of ticks since
/// the last timer interrupt.
pub fn cntp_tval_el0() i32 {
    const signed: isize = @bitCast(readReg("cntp_tval_el0"));
    return @truncate(signed);
}

/// Sleep the current ARM processor for the specified number of
/// microseconds `usecs`.
pub fn usleep(usecs: usize) void {
    const start = cntpct_el0();
    const end = cntfrq_el0() / 1000000 * usecs + start;
    while (cntpct_el0() < end) {}
}

const ExceptionLevelBits = packed struct(usize) {
    rsvd0: u2,
    exception_level: ExceptionLevel,
    pad: u60,
};

/// Possible exception levels the ARM processors can run in.
pub const ExceptionLevel = enum(u2) {
    el0,
    el1,
    el2,
    el3,
};

/// Returns the current ARM exception level.
pub fn currentEL() ExceptionLevel {
    const reg: ExceptionLevelBits = @bitCast(asm volatile(
        "mrs %[reg], currentel"
        : [reg] "=r" (-> usize)
    ));
    return reg.exception_level;
}
