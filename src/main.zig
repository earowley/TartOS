const serial = @import("rtos/io/serial.zig");
const mbox = @import("hardware/mbox.zig").mbox;

export fn main() noreturn {
    serial.initSerialStreams();
    serial.printf("firmware revision: 0x{X}\n",
        .{mbox.firmwareRevision()});
    serial.printf("core clock speed: {} MHz\n",
        .{mbox.clockSpeed(.core)/1000000});
    serial.printf("arm clock speed: {} MHz\n",
        .{mbox.clockSpeed(.arm)/1000000});

    while (true) {}
}
