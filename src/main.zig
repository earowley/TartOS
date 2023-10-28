const std = @import("std");
const serial = @import("rtos/io/serial.zig");
const mbox = @import("hardware/mbox.zig").mbox;
const hrng = @import("hardware/rng.zig").rng;
const rand = @import("rtos/rand.zig");
const StackTrace = std.builtin.StackTrace;

export fn main() noreturn {
    serial.initSerialStreams();
    hrng.init();
    serial.printf("firmware revision: 0x{X}\n",
        .{mbox.firmwareRevision()});
    serial.printf("core clock speed: {} MHz\n",
        .{mbox.clockSpeed(.core)/1000000});
    serial.printf("arm clock speed: {} MHz\n",
        .{mbox.clockSpeed(.arm)/1000000});
    serial.printf("Random value: {}\n", .{rand.between(u16, 1, 1000)});

    while (true) {}
}

pub fn panic(msg: []const u8, _: ?*StackTrace, _: ?usize) noreturn {
    serial.print("PANIC: ");
    serial.println(msg);

    while (true) {}
}
