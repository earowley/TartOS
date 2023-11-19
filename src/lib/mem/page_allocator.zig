const std = @import("std");
const page_size = @import("mem.zig").page_size;

/// Possible errors when allocating memory.
pub const AllocatorError = error {
    OutOfMemory,
    InvalidRequest,
};

/// An allocator for allocating physically contiguous pages. The max
/// number of pages that can be allocated at once is either 32 or 64,
/// depending on the architecture.
pub const PageAllocator = struct {
    allocated: std.DynamicBitSetUnmanaged,
    clusters: []u8,
    start: usize,

    /// Allocate `n` physically contiguous pages.
    pub fn allocPages(self: *PageAllocator, n: pageReqType())
      AllocatorError![][page_size]u8 {
        if (n == 0) return AllocatorError.InvalidRequest;
        const idx = self.findBestCluster(n) orelse return
            AllocatorError.OutOfMemory;
        const bit_offset = self.findClusterOffset(idx, n);
        const page = idx * @bitSizeOf(usize) + bit_offset;
        self.clusters[idx] -= n;
        self.allocated.setRangeValue(.{.start = page, .end = page + n},
            false);
        var result: [][page_size]u8 = undefined;
        result.len = n;
        result.ptr = @ptrFromInt(self.start + page * page_size);
        return result;
    }

    /// Free pages allocated by `allocPages`.
    pub fn freePages(self: *PageAllocator, pages: [][page_size]u8)
      void {
        const address = @intFromPtr(pages.ptr);
        if (address < self.start or address & (page_size - 1) != 0)
            return;
        const page = (address - self.start) / page_size;
        const idx = page / @bitSizeOf(usize);
        const bit_offset: u6 = @intCast(page & (@bitSizeOf(usize) - 1));
        const mask =
            if (pages.len == @bitSizeOf(usize))
                std.math.maxInt(usize)
            else
                ((@as(usize, 1) << @intCast(pages.len)) - 1) <<
                bit_offset;
        self.allocated.masks[idx] |= mask;
        const bits = self.allocated.masks[idx];
        var chain: u8 = @intCast(pages.len);
        if (bit_offset != 0) {
            var tm = @as(usize, 1) << (bit_offset - 1);
            while (tm != 0 and tm & bits == tm) : (tm >>= 1) {
                chain += 1;
            }
        }
        if (pages.len + bit_offset < @bitSizeOf(usize)) {
            var tm = @as(usize, 1) << @intCast(bit_offset + pages.len);
            while (tm != 0 and tm & bits == tm) : (tm <<= 1) {
                chain += 1;
            }
        }
        if (chain > self.clusters[idx])
            self.clusters[idx] = chain;
    }

    fn findBestCluster(self: PageAllocator, pages: u6) ?usize {
        for (self.clusters, 0..) |c, idx| {
            if (c >= pages) return idx;
        }
        return null;
    }

    fn findClusterOffset(self: PageAllocator, idx: usize, pages: u6)
      u8 {
        const cluster = self.allocated.masks[idx];
        const mask =
            if (pages == @bitSizeOf(usize))
                std.math.maxInt(usize)
            else
                (@as(usize, 1) << pages) - 1;
        const max_shift = @bitSizeOf(usize) - @as(usize, pages);
        for (0..max_shift) |shift| {
            const sm = mask << @intCast(shift);
            if (cluster & sm == sm) return @intCast(shift);
        }
        unreachable;
    }
};

fn pageReqType() type {
    return switch(@bitSizeOf(usize)) {
        32 => u5,
        64 => u6,
        else => unreachable,
    };
}
