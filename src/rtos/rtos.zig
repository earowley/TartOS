const std = @import("std");
const lib = @import("lib");
const hw = @import("hardware");
const core = @import("core.zig");
const serial = lib.io.serial;
const rand = lib.rand;
const Mailbox = hw.mbox.Mailbox;
const StackTrace = std.builtin.StackTrace;

const raw_psf align(@alignOf(lib.gfx.PCScreenFont)) = @embedFile(
    "assets/font.psf"
).*;
const font: *const lib.gfx.PCScreenFont = @ptrCast(&raw_psf);

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
    const fb = lib.gfx.FrameBuffer.init(1024, 768, .rgb) catch
        fatal("Unable to create FrameBuffer!", @src());
    var tty = lib.io.Terminal.init(
        &fb,
        font,
        10,
        30,
        0
    ) catch unreachable;
    const writer = tty.writer();
    writer.print("random value is: {}\n", .{rand.between(u16, 1, 1000)})
        catch unreachable;
    const spinners = [_]u8{'-', '\\', '|', '/'};
    const sx = tty.cursor_x;
    const sy = tty.cursor_y;

    while (true) {
        for (spinners) |g| {
            tty.writeASCIIByte(g);
            tty.cursor_x = sx;
            tty.cursor_y = sy;
            hw.arm.usleep(100000);
        }
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
