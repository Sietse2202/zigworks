const eadk_internal = @import("eadk_internal.zig");
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
        @truncate(randomU32());

    return @bitCast(raw);
}

pub fn randomInRange(comptime T: type, min: T, max: T) T {
    const info = @typeInfo(T);
    if (info != .int) @compileError("randomInRange only supports integer types");

    const Unsigned = std.meta.Int(.unsigned, @bitSizeOf(T));

    const n: Unsigned = @as(Unsigned, @bitCast(max)) -% @as(Unsigned, @bitCast(min)) +% 1;
    if (n == 0) return min;

    const max_val = std.math.maxInt(Unsigned);
    const threshold: Unsigned = (max_val -% n +% 1) % n;

    var x: Unsigned = @bitCast(randomInt(T));
    while (x < threshold) {
        x = @bitCast(randomInt(T));
    }

    return min +% @as(T, @bitCast(x % n));
}

pub fn randomFloat(comptime T: type) T {
    if (@typeInfo(T) != .float) @compileError("randomFloat only supports float types");
    return @as(T, @floatFromInt(randomU32())) / (@as(T, @floatFromInt(std.math.maxInt(u32))) + 1.0);
}

pub fn randomBool() bool {
    return randomInt(u1) == 1;
}

pub fn shuffle(comptime T: type, slice: []T) void {
    if (slice.len > std.math.maxInt(u32) + 1) @panic("slice too large for 32-bit RNG");
    var i: usize = slice.len;
    while (i > 1) {
        i -= 1;
        const j: usize = @intCast(randomInRange(u32, 0, @intCast(i)));
        std.mem.swap(T, &slice[i], &slice[j]);
    }
}
