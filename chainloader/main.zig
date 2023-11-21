const std = @import("std");
const lib = @import("lib");

export fn main() noreturn {
    const app: [*]u8 = @ptrFromInt(0x80000);
    _ = app;
    const uart = lib.io.serial.SerialStream.initUART()
        catch unreachable;
    const sz = uart.reader().readIntLittle(u32) catch unreachable;
    uart.writer().print("Kernel size: 0x{X}\n", .{sz})
        catch unreachable;
    while (true) {}
}
