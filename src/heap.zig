const std = @import("std");

export var errno: c_int = 0;
extern fn _sbrk(incr: c_int) ?*anyopaque;

pub const SbrkAllocator = struct {
    const Self = @This();

    const BlockHeader = struct {
        size: usize,
        is_free: bool,
        next: ?*BlockHeader,
    };

    free_list: ?*BlockHeader = null,

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (len == 0) return null;

        const alignment = @as(usize, 1) << @intCast(ptr_align.toByteUnits());
        const header_size = std.mem.alignForward(usize, @sizeOf(BlockHeader), alignment);
        const total_size = header_size + len;

        if (self.findFreeBlock(total_size, alignment)) |block| {
            block.is_free = false;
            const data_ptr = @as([*]u8, @ptrCast(block)) + header_size;
            return data_ptr;
        }

        const alloc_size = std.mem.alignForward(usize, total_size, 8);
        const raw_ptr = _sbrk(@intCast(alloc_size)) orelse return null;

        const block: *BlockHeader = @ptrCast(@alignCast(raw_ptr));
        block.* = .{
            .size = alloc_size,
            .is_free = false,
            .next = self.free_list,
        };

        self.free_list = block;

        const data_ptr = @as([*]u8, @ptrCast(block)) + header_size;
        return data_ptr;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf_align;
        _ = ret_addr;

        return new_len <= buf.len;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (buf.len == 0) return;

        const alignment = @as(usize, 1) << @intCast(buf_align.toByteUnits());
        const header_size = std.mem.alignForward(usize, @sizeOf(BlockHeader), alignment);
        const block_ptr = @as([*]u8, @ptrCast(buf.ptr)) - header_size;
        const block: *BlockHeader = @ptrCast(@alignCast(block_ptr));

        block.is_free = true;

        self.coalesce();
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = ret_addr;

        const alignment = @as(usize, 1) << @intCast(buf_align.toByteUnits());
        const header_size = std.mem.alignForward(usize, @sizeOf(BlockHeader), alignment);
        const block_ptr = @as([*]u8, @ptrCast(buf.ptr)) - header_size;
        const block: *BlockHeader = @ptrCast(@alignCast(block_ptr));

        const available_size = block.size - header_size;

        if (new_len <= available_size) {
            return buf.ptr;
        }

        if (block.next) |next_block| {
            if (next_block.is_free) {
                const block_end = @intFromPtr(block) + block.size;
                const next_start = @intFromPtr(next_block);

                if (block_end == next_start) {
                    const new_block_size = block.size + next_block.size;
                    const new_available = new_block_size - header_size;

                    if (new_len <= new_available) {
                        block.size = new_block_size;
                        block.next = next_block.next;
                        return buf.ptr;
                    }
                }
            }
        }

        return null;
    }

    fn findFreeBlock(self: *Self, size: usize, alignment: usize) ?*BlockHeader {
        var current = self.free_list;

        while (current) |block| {
            if (block.is_free and block.size >= size) {
                const header_size = std.mem.alignForward(usize, @sizeOf(BlockHeader), alignment);
                const data_ptr = @intFromPtr(block) + header_size;

                if (std.mem.isAligned(data_ptr, alignment)) {
                    return block;
                }
            }
            current = block.next;
        }

        return null;
    }

    fn coalesce(self: *Self) void {
        var current = self.free_list;

        while (current) |block| {
            if (block.is_free) {
                var next = block.next;

                while (next) |next_block| {
                    const block_end = @intFromPtr(block) + block.size;
                    const next_start = @intFromPtr(next_block);

                    if (next_block.is_free and block_end == next_start) {
                        block.size += next_block.size;
                        block.next = next_block.next;
                        next = block.next;
                    } else {
                        break;
                    }
                }
            }
            current = block.next;
        }
    }
};
