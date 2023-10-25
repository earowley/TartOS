const gpio = @import("hardware/gpio.zig").gpio;
const aux  = @import("hardware/aux.zig").aux;

export fn main() noreturn {
    const message = "Hello world!";
    gpio.fnSel(14, .alt5);
    gpio.fnSel(15, .alt5);
    gpio.pud(14, .disable);
    gpio.pud(15, .disable);
    aux.muEnable();
    aux.muDisableComm();
    aux.muSetDataSize(.mu8bit);
    aux.muClearFIFOs();
    aux.mu_baud = 270;
    aux.muEnableComm();

    for (message) |c| {
        aux.muSendByte(c);
    }

    while (true) {}
}
