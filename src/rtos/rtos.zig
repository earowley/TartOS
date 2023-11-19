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

export fn handleIRQ() void {
    hw.arm.writeReg("cntp_tval_el0", @intCast(hw.arm.cntfrq_el0()));
}

export fn main() noreturn {
    core.initCore();
    const fb = lib.gfx.FrameBuffer.init(1024, 768, .rgb);
    var tty = lib.io.Terminal.init(
        &fb,
        font,
        10,
        30,
        0
    ) catch unreachable;
    const writer = tty.writer();
    const p = lib.mem.page_allocator.allocPages(60) catch unreachable;
    writer.print("{} page @ 0x{X}\n", .{p.len, @intFromPtr(p.ptr)})
        catch unreachable;
    writer.print("cluster0: {}  bits0: 0x{X}\n", .{
        lib.mem.page_allocator.clusters[0],
        lib.mem.page_allocator.allocated.masks[0]
    }) catch unreachable;
    lib.mem.page_allocator.freePages(p);
    writer.print("cluster0: {}  bits0: 0x{X}\n", .{
        lib.mem.page_allocator.clusters[0],
        lib.mem.page_allocator.allocated.masks[0]
    }) catch unreachable;

    while (true) {}
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
