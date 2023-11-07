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
    const grid = lib.gfx.Grid.init(
        &fb, 20, 20, 10, 10, 3
    ) catch unreachable;

    while (true) {
        for (0..grid.height) |y| {
            for (0..grid.width) |x| {
                var sect = grid.gridSectionUnchecked(@intCast(x), @intCast(y));
                const rr = rand.between(u8, 0, 255);
                const gr = rand.between(u8, 0, 255);
                const br = rand.between(u8, 0, 255);
                while (sect.next()) |pix| {
                    pix.rgb.r = rr;
                    pix.rgb.g = gr;
                    pix.rgb.b = br;
                }
            }
        }
        hw.arm.usleep(250000);
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
