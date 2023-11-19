const pa = @import("page_allocator.zig");
pub const page_size = 4096;
pub const PageAllocator = pa.PageAllocator;
pub var page_allocator: PageAllocator = undefined;
