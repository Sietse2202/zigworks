//! Keyboard/input module for zigworks, allows for checking if keys are pressed.

const eadk = @import("root.zig").eadk_internal;

pub const Key = enum(u8) {
    left = 0,
    up = 1,
    down = 2,
    right = 3,
    ok = 4,
    back = 5,
    home = 6,
    on_off = 8,
    shift = 12,
    alpha = 13,
    xnt = 14,
    @"var" = 15,
    toolbox = 16,
    backspace = 17,
    exp = 18,
    ln = 19,
    log = 20,
    imaginary = 21,
    comma = 22,
    power = 23,
    sine = 24,
    cosine = 25,
    tangent = 26,
    pi = 27,
    sqrt = 28,
    square = 29,
    seven = 30,
    eight = 31,
    nine = 32,
    left_paren = 33,
    right_paren = 34,
    four = 36,
    five = 37,
    six = 38,
    multiplication = 39,
    division = 40,
    one = 42,
    two = 43,
    three = 44,
    plus = 45,
    minus = 46,
    zero = 48,
    dot = 49,
    ee = 50,
    ans = 51,
    exe = 52,
};

pub const KeyboardState = struct {
    state: u64,

    const Self = @This();

    pub fn isKeyDown(self: *const Self, key: Key) bool {
        return eadk.eadk_keyboard_key_down(self.state, @intFromEnum(key));
    }

    pub fn areAllKeysDown(self: *const Self, keys: []const Key) bool {
        for (keys) |key|
            if (!self.isKeyDown(key))
                return false;

        return true;
    }

    pub fn areAnyKeysDown(self: *const Self, keys: []const Key) bool {
        for (keys) |key|
            if (self.isKeyDown(key))
                return true;

        return false;
    }
};

pub fn waitUntilPressed(key: Key) void {
    var current_scan = scan();
    while (!current_scan.isKeyDown(key))
        current_scan = scan();
}

pub fn waitUntilAnyPressed(keys: []const Key) void {
    var current_scan = scan();
    while (!current_scan.areAnyKeysDown(keys))
        current_scan = scan();
}

pub fn waitUntilReleased(key: Key) void {
    var current_scan = scan();
    while (current_scan.isKeyDown(key))
        current_scan = scan();
}

pub fn waitUntilAllReleased(keys: []const Key) void {
    var current_scan = scan();
    while (true) {
        current_scan = scan();

        if (!current_scan.areAnyKeysDown(keys))
            break;
    }
}

pub fn scan() KeyboardState {
    return .{ .state = eadk.eadk_keyboard_scan() };
}
