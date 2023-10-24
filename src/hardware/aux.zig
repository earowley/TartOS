pub const AUX_ENABLE = register(0x215004);
pub const AUX_MU_IO = register(0x215040);
pub const AUX_MU_IER = register(0x215044);
pub const AUX_MU_IIR = register(0x215048);
pub const AUX_MU_LCR = register(0x21504C);
pub const AUX_MU_MCR = register(0x215050);
pub const AUX_MU_LSR = register(0x215054);
pub const AUX_MU_MSR = register(0x215058);
pub const AUX_MU_SCRATCH = register(0x21505C);
pub const AUX_MU_CNTL = register(0x215060);
pub const AUX_MU_STAT = register(0x215064);
pub const AUX_MU_BAUD = register(0x215068);

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
