const std = @import("std");
const CalculatorModel = @import("root").CalculatorModel;

fn readU32At(addr: usize) u32 {
    return @as(*const u32, @ptrFromInt(addr)).*;
}

fn readU16At(addr: usize) u16 {
    return @as(*const u16, @ptrFromInt(addr)).*;
}

fn isValid(model: CalculatorModel) bool {
    // magic
    return readU32At(storageAddress(model)) == @byteSwap(@as(u32, 0xBADD0BEE));
}

fn storageAddress(model: CalculatorModel) usize {
    return readU32At(model.userlandAddress() + 0xC);
}

fn storageSize(model: CalculatorModel) usize {
    return readU32At(model.userlandAddress() + 0x10);
}

fn nextFree(model: CalculatorModel) ?usize {
    const base = storageAddress(model);
    const end = base + storageSize(model);
    if (!isValid(model)) return null;

    var offset = base + 4;
    while (offset < end) {
        const size = readU16At(offset);
        if (size == 0) return offset;
        offset += size;
    }
    return end;
}

const RecordIterator = struct {
    offset: usize,
    end: usize,

    const Record = struct {
        name: [:0]const u8,
        content: []const u8,
    };

    fn init(model: CalculatorModel) ?RecordIterator {
        const base = storageAddress(model);
        if (!isValid(model)) return null;
        return .{ .offset = base + 4, .end = base + storageSize(model) };
    }

    fn next(self: *RecordIterator) ?Record {
        if (self.offset >= self.end) return null;

        const record_size = readU16At(self.offset);
        if (record_size == 0) return null;

        const name_ptr: [*:0]const u8 = @ptrFromInt(self.offset + 2);
        const name_len = std.mem.len(name_ptr);
        const name: [:0]const u8 = name_ptr[0..name_len :0];

        const content_offset = self.offset + 2 + name_len + 1;
        const content_len = record_size - 2 - name_len - 1;
        const content = @as([*]const u8, @ptrFromInt(content_offset))[0..content_len];

        self.offset += record_size;
        return .{ .name = name, .content = content };
    }
};

pub fn fileExists(model: CalculatorModel, name: []const u8) bool {
    var iter = RecordIterator.init(model) orelse return false;
    while (iter.next()) |record| {
        if (std.mem.eql(u8, record.name, name)) return true;
    }
    return false;
}

pub fn listFiles(model: CalculatorModel, buffer: [][]const u8) error{InvalidStorage}![][]const u8 {
    var iter = RecordIterator.init(model) orelse return error.InvalidStorage;
    var count: usize = 0;
    while (iter.next()) |record| {
        if (count >= buffer.len) break;
        buffer[count] = record.name;
        count += 1;
    }
    return buffer[0..count];
}

pub fn listFilesWithExtension(
    model: CalculatorModel,
    buffer: [][]const u8,
    extension: []const u8,
) error{InvalidStorage}![][]const u8 {
    var iter = RecordIterator.init(model) orelse return error.InvalidStorage;
    var count: usize = 0;
    while (iter.next()) |record| {
        if (count >= buffer.len) break;
        if (std.mem.endsWith(u8, record.name, extension)) {
            buffer[count] = record.name;
            count += 1;
        }
    }
    return buffer[0..count];
}

pub fn readFile(model: CalculatorModel, filename: []const u8) error{ReadFile}![]const u8 {
    var iter = RecordIterator.init(model) orelse return error.ReadFile;
    while (iter.next()) |record| {
        if (std.mem.eql(u8, record.name, filename)) return record.content;
    }
    return error.ReadFile;
}

pub fn writeToFile(model: CalculatorModel, filename: []const u8, content: []const u8) error{WriteFile}!void {
    const free_addr = nextFree(model) orelse
        return error.WriteFile;

    const total_size: u16 = std.math.cast(u16, 2 + filename.len + 1 + content.len) orelse
        return error.WriteFile;
    const storage_end = storageAddress(model) + storageSize(model);

    if (free_addr + total_size > storage_end)
        return error.WriteFile;

    @as(*u16, @ptrFromInt(free_addr)).* = total_size;
    const name_dest: [*]u8 = @ptrFromInt(free_addr + 2);
    @memcpy(name_dest[0..filename.len], filename);
    name_dest[filename.len] = 0;
    const content_dest: [*]u8 = @ptrFromInt(free_addr + 2 + filename.len + 1);
    @memcpy(content_dest[0..content.len], content);

    const zero_start: [*]u8 = @ptrFromInt(free_addr + total_size);
    @memset(zero_start[0 .. storage_end - (free_addr + total_size)], 0);
}

pub fn eraseFile(model: CalculatorModel, filename: []const u8) error{EraseFile}!void {
    if (!isValid(model)) return error.EraseFile;

    var iter = RecordIterator.init(model) orelse
        return error.EraseFile;

    const addr = while (iter.next()) |record| {
        if (std.mem.eql(u8, record.name, filename))
            break iter.offset - record.name.len - 3;
    } else return error.EraseFile;

    const record_size = readU16At(addr);
    const free_addr = nextFree(model) orelse return error.EraseFile;

    std.mem.copyForwards(
        u8,
        @as([*]u8, @ptrFromInt(addr))[0 .. free_addr - addr - record_size],
        @as([*]u8, @ptrFromInt(addr + record_size))[0 .. free_addr - addr - record_size],
    );
    @memset(@as([*]u8, @ptrFromInt(free_addr - record_size))[0..record_size], 0);
}
