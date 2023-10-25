const serial = @import("rtos/io/serial.zig");

export fn main() noreturn {
    serial.initMU();
    serial.println("Hello world!");
    serial.println("Second line");
    var magic: u32 = 42;
    serial.printf("The magic number is: {}\n", .{magic});

    while (true) {}
}
