const std = @import("std");
const lib = @import("lib");
const hw = @import("hardware");
const serial = lib.io.serial;
const rand = lib.rand;
const Mailbox = hw.mbox.Mailbox;
const StackTrace = std.builtin.StackTrace;

export fn main() noreturn {
    serial.initSerialStreams();
    hw.rng.rng.init();
    serial.printf("serial number: 0x{X}\n",
        .{Mailbox.serialNumber()});
    serial.printf("firmware revision: 0x{X}\n",
        .{Mailbox.firmwareRevision()});
    serial.printf("core clock speed: {} MHz\n",
        .{Mailbox.clockSpeed(.core)/1000000});
    serial.printf("arm clock speed: {} MHz\n",
        .{Mailbox.clockSpeed(.arm)/1000000});
    serial.printf("Random value: {}\n", .{rand.between(u16, 1, 1000)});

    while (true) {}
}

pub fn panic(msg: []const u8, _: ?*StackTrace, _: ?usize) noreturn {
    serial.print("PANIC: ");
    serial.println(msg);

    while (true) {}
}
