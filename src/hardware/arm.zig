const ExceptionLevelBits = packed struct(usize) {
    rsvd0: u2,
    exception_level: ExceptionLevel,
    pad: u60,
};

/// Possible exception levels the ARM processor can be running in.
pub const ExceptionLevel = enum(u2) {
    el0,
    el1,
    el2,
    el3,
};

/// Wait for the ARM CPU to complete at least `n` cycles. The amount
/// of wall time taken in this function is dependent on the clock
/// speed of the CPU.
pub fn waitCycles(n: usize) void {
    for (0..n) |_| {
        asm volatile("nop");
    }
}

/// Returns the current ARM counter frequency.
pub fn cntfreq() usize {
    return asm volatile(
        "mrs %[reg], cntfrq_el0"
        : [reg] "=r" (-> usize)
    );
}

/// Returns the current ARM counter value.
pub fn cntpct() usize {
    return asm volatile(
        "mrs %[reg], cntpct_el0"
        : [reg] "=r" (-> usize)
    );
}

/// Sleep the current ARM processor for the specified number of
/// microseconds `usecs`.
pub fn usleep(usecs: usize) void {
    const start = cntpct();
    const end = cntfreq() / 1000000 * usecs + start;
    while (cntpct() < end) {}
}

/// Returns the current ARM exception level.
pub fn currentEL() ExceptionLevel {
    const reg: ExceptionLevelBits = @bitCast(asm volatile(
        "mrs %[reg], currentel"
        : [reg] "=r" (-> usize)
    ));
    return reg.exception_level;
}
