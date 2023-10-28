/// Wait for the ARM CPU to complete `n` cycles. The amount of clock
/// time taken in this function is dependent on the clock speed of the
/// CPU.
pub fn waitCycles(n: usize) void {
    for (0..n) |_| {
        asm volatile("nop");
    }
}
