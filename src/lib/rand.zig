const std = @import("std");
const hrng = @import("hardware").rng.RNG.resource;

fn betweenHRNG(a: u64, b: u64) u64 {
    var min: u64 = undefined;
    var max: u64 = undefined;

    if (a == b)
        return a;

    if (a > b) {
        min = b;
        max = a;
    } else {
        min = a;
        max = b;
    }

    const r = (@as(u64, hrng.rand()) << 32) | hrng.rand();

    return r % (max + 1 - min) + min;
}

/// Returns a random number in the range [a,b].
pub fn between(comptime T: type, a: T, b: T) T {
    comptime {std.debug.assert(@typeInfo(T).Int.bits <= 64);}
    return @truncate(betweenHRNG(a, b));
}
