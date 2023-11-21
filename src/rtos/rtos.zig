const std = @import("std");
const lib = @import("lib");
const hw = @import("hardware");
const core = @import("core.zig");
const StackTrace = std.builtin.StackTrace;

const LogoHeader = struct {
    w: u16,
    h: u16,
};

export fn handleIRQ() void {
}

export fn main() noreturn {
    core.initCore();
    const fb = lib.gfx.FrameBuffer.init(1024, 768, .rgb);
    const sd = lib.SDCard.init() catch unreachable;
    var buffer: [lib.SDCard.block_size_dw]u32 = undefined;
    sd.readBlock(0, &buffer);
    const hdr = @as(*const LogoHeader, @ptrCast(&buffer)).*;
    var rect = fb.iterRect(
        (fb.width - hdr.w) / 2,
        (fb.height - hdr.h) / 2,
        hdr.w,
        hdr.h
    );
    const pixels = @as(u32, hdr.w) * @as(u32, hdr.h);
    var pixels_written: u32 = 0;
    var pixel_data: []const u32 = buffer[1..];
    var block: u32 = 1;

    draw: while (pixels_written < pixels) : (block += 1) {
        const to_copy = @min(pixel_data.len, pixels - pixels_written);
        for (pixel_data[0..to_copy]) |raw| {
            const p = rect.next() orelse break :draw;
            p.val = raw;
        }
        pixels_written += to_copy;
        sd.readBlock(block, &buffer);
        pixel_data = buffer[0..];
    }

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
