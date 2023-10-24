pub fn waitCycles(n: usize) void {
    for (0..n) |_| {
        asm volatile("nop");
    }
}
