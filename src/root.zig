//! Zig bindings for the [NumWorks](https://github.com/numworks/epsilon) SDK

const std = @import("std");

pub const syscall = @import("syscall.zig");
pub const display = @import("display.zig");
pub const keyboard = @import("keyboard.zig");

pub const timing = struct {
    /// Sleep for `ms` ms
    pub fn sleepMillis(ms: u32) void {
        syscall.svc1(.timing_msleep, ms);
    }

    /// Sleep for `us` μs
    pub fn sleepMicros(us: u32) void {
        syscall.svc1(.timing_usleep, us);
    }

    /// Get the time the calculator has been on for in milliseconds
    pub fn millis() u64 {
        return syscall.svc0r(.timing_millis);
    }
};

pub const heap = @import("heap.zig");

/// All functions inside this namespace appear to be broken and are thus deprecated,
/// but are kept in for consistency with the C Header
pub const battery = struct {
    /// Is the calculator charging or not (deprecated)
    pub fn isCharging() bool {
        return syscall.svc0r(.battery_is_charging) != 0;
    }

    /// Level of the battery, always in the range [0, 100] (deprecated)
    pub fn getBatteryLevel() u8 {
        return @truncate(syscall.svc0r(.battery_level));
    }

    /// Voltage the battery uses at the time of calling (deprecated)
    pub fn batteryVoltage() f32 {
        return syscall.svc0s(.battery_voltage);
    }

    /// Whether or not the calculator is plugged in (to a computer presumably) (deprecated)
    pub fn isPluggedIn() bool {
        return syscall.svc0r(.usb_is_plugged) != 0;
    }
};

pub const fs = @import("fs.zig");

extern var eadk_external_data: [*]const u8;
extern var eadk_external_data_size: usize;
pub const external_data: []const u8 = eadk_external_data[0..eadk_external_data_size];

pub const random = @import("random.zig");

pub const CalculatorModel = enum(u2) {
    unknown = 0,
    @"N0110/N0115" = 1,
    N0120 = 2,
    _,

    fn readU32At(addr: usize) u32 {
        return @as(*const u32, @ptrFromInt(addr)).*;
    }

    pub fn infer() CalculatorModel {
        const magic: u32 = @byteSwap(0xfeedc0de);

        const n0110Count: u2 =
            @intFromBool(readU32At(0x90010000) == magic) +
            @intFromBool(readU32At(0x90410000) == magic);
        const n0120Count: u2 =
            @intFromBool(readU32At(0x90020000) == magic) +
            @intFromBool(readU32At(0x90420000) == magic);

        if (n0110Count > 0 and n0120Count == 0) return .@"N0110/N0115";
        if (n0120Count > 0 and n0110Count == 0) return .N0120;
        return .unknown;
    }

    pub fn userlandAddress(model: CalculatorModel) usize {
        return switch (model) {
            .@"N0110/N0115" => readU32At(0x20000004) + 0x10000 - 0x8,
            .N0120 => readU32At(0x24000004) + 0x20000 - 0x8,
            else => readU32At(0x24000004) + 0x20000 - 0x8,
        };
    }
};

pub const AppMetadata = struct {
    name: [:0]const u8,
    app_icon: []const u8,
    api_level: u32 = 0,
};

pub fn init(comptime metadata: AppMetadata) void {
    exportMain();

    const name_as_array: *const [metadata.name.len:0]u8 = metadata.name[0..];
    const icon_as_array: *const [metadata.app_icon.len]u8 = metadata.app_icon[0..];

    @export(name_as_array, .{ .linkage = .strong, .section = ".rodata", .name = "eadk_app_name" });
    @export(&metadata.api_level, .{ .linkage = .strong, .section = ".rodata", .name = "eadk_api_level" });
    @export(icon_as_array, .{ .linkage = .strong, .section = ".rodata", .name = "eadk_app_icon" });
}

fn exportMain() void {
    const root = @import("root");
    if (!@hasDecl(root, "main")) {
        @compileError("there should be a public `main` function in the root");
    }

    const main = root.main;
    const Main = @TypeOf(main);

    switch (@typeInfo(Main)) {
        .@"fn" => {},
        else => @compileError("`main` must be a function"),
    }

    const exportee = struct {
        pub fn exportee() callconv(.c) void {
            main();
        }
    }.exportee;

    @export(&exportee, .{ .linkage = .strong, .name = "main" });
}
