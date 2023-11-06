pub const rand = @import("rand.zig");
pub const io = @import("io/io.zig");
pub const gfx = @import("gfx/gfx.zig");
const hw = @import("hardware");

/// Hardware initialization function. Should always be called by the
/// reset vector if any library functions are used.
export fn initHardware() void {    
    hw.rng.RNG.resource.init();
}
