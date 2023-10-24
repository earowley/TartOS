pub const mmio_base = 0x3F000000;
pub const GPFSEL0 = register(0x200000);
pub const GPFSEL1 = register(0x200004);
pub const GPFSEL2 = register(0x200008);
pub const GPFSEL3 = register(0x20000C);
pub const GPFSEL4 = register(0x200010);
pub const GPFSEL5 = register(0x200014);
pub const GPPUD

pub fn register(comptime offset: comptime_int) *volatile u32 {
    return @ptrFromInt(mmio_base + offset);
}

pub fn uartInit() void {
    AUX_ENABLE.* |= 1;
    AUX_MU_CNTL.* = 0;
    AUX_MU_LCR.* = 3;
    AUX_MU_IER.* = 0;
    AUX_MU_IIR.* = 0xC6;
    AUX_MU_BAUD.* = 270;
    var reg = GPFSEL1.*;
    reg &= ~@as(@TypeOf(reg), (7 << 12) | (7 << 15));
    reg |= (2 << 12) | (2 << 15);
    GPFSEL1.* = reg;
}
