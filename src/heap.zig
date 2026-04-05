const std = @import("std");

export var errno: c_int = 0;
extern fn _sbrk(incr: c_int) ?*anyopaque;

pub const SbrkAllocator = std.heap.SbrkAllocator(struct {
    pub fn sbrk(increment: usize) usize {
        return @intFromPtr(_sbrk(@intCast(increment)));
    }
}.sbrk);

test SbrkAllocator {
    _ = SbrkAllocator;
}
