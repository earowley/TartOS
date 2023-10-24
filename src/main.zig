const mmio = @import("mmio.zig");

export fn main() noreturn {
    mmio.uartInit();
    while (true) {}
}
