const eadk_internal = @import("root");
const std = @import("std");

inline fn randomU32() u32 {
    return eadk_internal.eadk_random();
}

pub fn randomInt(comptime T: type) T {
    const info = @typeInfo(T);
    if (info != .int) @compileError("randomInt only supports integer types");

    const bits = @bitSizeOf(T);
    if (bits > 32) @compileError("randomInt only supports types up to 32 bits");

    const Unsigned = std.meta.Int(.unsigned, bits);
    const raw: Unsigned = if (bits == 32)
        randomU32()
    else
        @truncate(randomU32() >> (32 - bits));

    return @bitCast(raw);
}

pub fn randomInRange(comptime T: type, min: T, max: T) T {
    const info = @typeInfo(T);
    if (info != .int) @compileError("randomInRange only supports integer types");

    const Unsigned = std.meta.Int(.unsigned, @bitSizeOf(T));
    const max_val = std.math.maxInt(Unsigned);

    const n: Unsigned = @bitCast(max - min + 1);
    if (n == 0) return min; // n wrapped, meaning the full range was requested

    const rem = max_val % n;
    var x: Unsigned = @bitCast(randomInt(T));

    var safety: usize = 1000;
    while (x > max_val - rem - 1) : (safety -= 1) {
        if (safety == 0) break; // RNG appears broken, bail out
        x = @bitCast(randomInt(T));
    }

    return min + @as(T, @bitCast(x % n));
}

pub fn randomFloat(comptime T: type) T {
    if (@typeInfo(T) != .float) @compileError("randomFloat only supports float types");
    return @as(T, @floatFromInt(randomU32())) / @as(T, @floatFromInt(std.math.maxInt(u32)));
}

pub fn randomBool() bool {
    return randomInt(u1) == 1;
}

pub fn shuffle(comptime T: type, slice: []T) void {
    var i: usize = slice.len;
    while (i > 1) {
        i -= 1;
        const j: usize = @intCast(randomInRange(u32, 0, @intCast(i)));
        std.mem.swap(T, &slice[i], &slice[j]);
    }
}
