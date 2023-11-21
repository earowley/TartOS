pub const gfx = @import("gfx/gfx.zig");
pub const io = @import("io/io.zig");
pub const mem = @import("mem/mem.zig");
pub const rand = @import("rand.zig");
pub const Iterator = @import("iterator.zig").Iterator;
pub const SDCard = @import("io/sd.zig").SDCard;
const hw = @import("hardware");
const std = @import("std");

/// Hardware initialization function. Should always be called by the
/// reset vector if any library functions are used.
export fn initHardware(kstart: usize, ksize: usize) void {
    hw.RNG.resource.init();
    initAllocator(kstart, ksize);
}

fn initAllocator(kstart: usize, ksize: usize) void {
    const mi = hw.mbox.Mailbox.meminfo();
    const kend = kstart + ksize;
    const reserve = mem.page_size;
    const max_page_count = (mi.arm.len - kend - reserve) /
        mem.page_size;
    const max_res_bytes = std.mem.alignForward(
        usize,
        (max_page_count >> 3) +
        @as(usize, if (max_page_count & 7 != 0) 1 else 0),
        @sizeOf(usize));
    const max_grp_bytes = max_res_bytes / @sizeOf(usize);
    const alloc_size = std.mem.alignForward(usize,
        @max(reserve, max_res_bytes + max_grp_bytes), mem.page_size);
    const actual_page_count = (mi.arm.len - kend - alloc_size) /
        mem.page_size;
    const actual_res_bytes = std.mem.alignForward(
        usize,
        (actual_page_count >> 3) +
        @as(usize, if (actual_page_count & 7 != 0) 1 else 0),
        @sizeOf(usize));
    const actual_grp_bytes = actual_res_bytes / @sizeOf(usize);
    mem.page_allocator.allocated.bit_length = actual_page_count;
    mem.page_allocator.allocated.masks = @ptrFromInt(kend);
    mem.page_allocator.clusters.ptr = @ptrFromInt(
        kend + actual_res_bytes);
    mem.page_allocator.clusters.len = actual_grp_bytes;
    mem.page_allocator.start = kend + alloc_size;
    mem.page_allocator.allocated.setRangeValue(.{.start = 0,
        .end = actual_page_count}, true);
    var rem_pages = actual_page_count;
    for (mem.page_allocator.clusters) |*c| {
        const chunk: u8 = @min(@bitSizeOf(usize), rem_pages);
        c.* = chunk;
        rem_pages -= chunk;
    }
}
