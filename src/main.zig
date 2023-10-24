const gpio = @import("hardware/gpio.zig").gpio;

export fn main() noreturn {
    gpio.fnSel(14, .alt5);
    gpio.fnSel(15, .alt5);
    gpio.pud(14, .disable);
    gpio.pud(15, .disable);
    while (true) {}
}
