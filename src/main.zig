const gpio = @import("hardware/gpio.zig").gpio;
const aux  = @import("hardware/aux.zig").aux;

export fn main() noreturn {
    gpio.fnSel(14, .alt5);
    gpio.fnSel(15, .alt5);
    aux.muEnable();
    aux.muDisableComm();
    aux.muSetDataSize(.mu8bit);
    aux.muClearFIFOs();
    aux.mu_baud = 270;
    aux.muEnableComm();

    const message = "Hello world!";

    for (message) |c| {
        aux.muSendByte(c);
    }

    aux.muSendByte('\r');
    aux.muSendByte('\n');

    while (true) {}
}
