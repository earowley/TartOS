pub const gfx = @import("gfx/gfx.zig");
pub const io = @import("io/io.zig");
pub const rand = @import("rand.zig");
pub const SDCard = @import("io/sd.zig").SDCard;
const hw = @import("hardware");

/// Hardware initialization function. Should always be called by the
/// reset vector if any library functions are used.
export fn initHardware() void {    
    hw.RNG.resource.init();
}
