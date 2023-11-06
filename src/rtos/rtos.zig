const std = @import("std");
const lib = @import("lib");
const hw = @import("hardware");
const core = @import("core.zig");
const serial = lib.io.serial;
const rand = lib.rand;
const Mailbox = hw.mbox.Mailbox;
const StackTrace = std.builtin.StackTrace;

export fn main() noreturn {
    core.initCore();
    core.printf("serial number: 0x{X}\n",
        .{Mailbox.serialNumber()});
    core.printf("firmware revision: 0x{X}\n",
        .{Mailbox.firmwareRevision()});
    core.printf("core clock speed: {} MHz\n",
        .{Mailbox.clockSpeed(.core)/1000000});
    core.printf("arm clock speed: {} MHz\n",
        .{Mailbox.clockSpeed(.arm)/1000000});
    core.printf("Random value: {}\n", .{rand.between(u16, 1, 1000)});
    const fb = lib.gfx.FrameBuffer.init(1024, 768, .rgb) catch
        fatal("Unable to create FrameBuffer!", @src());
    core.printf("Framebuffer: {}\n", .{fb});

    while (true) {
        for (0..fb.height) |y| {
            for (0..fb.width) |x| {
                const p = fb.pixelAt(@intCast(x), @intCast(y));
                p.rgb.r = 255;
                p.rgb.g = 0;
                p.rgb.b = 0;
            }
        }
        hw.arm.usleep(500000);
        for (0..fb.height) |y| {
            for (0..fb.width) |x| {
                const p = fb.pixelAt(@intCast(x), @intCast(y));
                p.rgb.r = 0;
                p.rgb.g = 255;
                p.rgb.b = 0;
            }
        }
        hw.arm.usleep(500000);
        for (0..fb.height) |y| {
            for (0..fb.width) |x| {
                const p = fb.pixelAt(@intCast(x), @intCast(y));
                p.rgb.r = 0;
                p.rgb.g = 0;
                p.rgb.b = 255;
            }
        }
        hw.arm.usleep(500000);
    }
}

pub fn panic(msg: []const u8, _: ?*StackTrace, _: ?usize) noreturn {
    core.print("PANIC: ");
    core.println(msg);

    while (true) {}
}

fn fatal(msg: []const u8, src: std.builtin.SourceLocation) noreturn {
    std.debug.panic("FATAL@{s}:{s}:{} - {s}", .{src.file,
        src.fn_name, src.line, msg});
}
