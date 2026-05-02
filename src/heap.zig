const std = @import("std");

export var errno: c_int = 0;
extern fn _sbrk(incr: c_int) ?*anyopaque;

pub fn sbrk(increment: usize) usize {
    return @intFromPtr(_sbrk(@intCast(increment)));
}

pub const SbrkAllocator = std.heap.SbrkAllocator(sbrk);

test SbrkAllocator {
    _ = sbrk;
    _ = SbrkAllocator;
}
