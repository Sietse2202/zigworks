//! Zig bindings for the [NumWorks](https://github.com/numworks/epsilon) SDK

/// The C header that the library wraps
pub const eadk_internal = @import("eadk_internal.zig");
const std = @import("std");

pub const display = @import("display.zig");

pub const keyboard = @import("keyboard.zig");

pub const timing = struct {
    /// Sleep for `ms` ms
    pub fn sleepMillis(ms: u32) void {
        eadk_internal.eadk_timing_msleep(ms);
    }

    /// Sleep for `us` μs
    pub fn sleepMicros(us: u32) void {
        eadk_internal.eadk_timing_usleep(us);
    }

    /// Get the time the calculator has been on for in milliseconds
    pub fn millis() u64 {
        return eadk_internal.eadk_timing_millis();
    }
};

pub const heap = @import("heap.zig");

/// This module appears to be broken and is thus deprecated, but is kept in for consistency with the C Header
pub const battery = struct {
    /// Is the calculator charging or not (deprecated)
    pub fn isCharging() bool {
        return eadk_internal.eadk_battery_is_charging();
    }

    /// Level of the battery, always in the range [0, 100] (deprecated)
    pub fn getBatteryLevel() u8 {
        return eadk_internal.eadk_battery_level();
    }

    /// Voltage the battery uses at the time of calling (deprecated)
    pub fn batteryVoltage() f32 {
        return eadk_internal.eadk_battery_voltage();
    }

    /// Whether or not the calculator is plugged in (to a computer presumably) (deprecated)
    pub fn isPluggedIn() bool {
        return eadk_internal.eadk_usb_is_plugged();
    }
};

pub const fs = @import("fs.zig");

/// Experimental and not yet tested.
pub const external_data: []const u8 = eadk_internal.eadk_external_data[0..eadk_internal.eadk_external_data_size];

pub const random = @import("random.zig");

pub const CalculatorModel = enum(u2) {
    unknown = 0,
    @"N0110/N0115" = 1,
    N0120 = 2,
    _,

    fn readU32At(addr: usize) u32 {
        return @as(*const u32, @ptrFromInt(addr)).*;
    }

    pub fn get() CalculatorModel {
        const magic: u32 = @byteSwap(0xfeedc0de);

        const n0110Count: u2 =
            @intFromBool(readU32At(0x90010000) == magic) +
            @intFromBool(readU32At(0x90410000) == magic);
        const n0120Count: u2 =
            @intFromBool(readU32At(0x90020000) == magic) +
            @intFromBool(readU32At(0x90420000) == magic);

        if (n0110Count > 0 and n0120Count == 0) return .@"N0110/N0115";
        if (n0120Count > 0 and n0110Count == 0) return .N0120;
        return .Unknown;
    }

    pub fn userlandAddress(model: CalculatorModel) usize {
        return switch (model) {
            .@"N0110/N0115" => readU32At(0x20000004) + 0x10000 - 0x8,
            .N0120 => readU32At(0x20000004) + 0x20000 - 0x8,
            else => readU32At(0x20000004) + 0x20000 - 0x8,
        };
    }
};

pub const MetaData = struct {
    name: [:0]const u8,
    api_level: u32 = 0,
    icon: []const u8,

    /// Convenience function for setting the required metadata in the final elf, if you don't use the symbols, zig will
    /// optimize them away, so be sure to do something like this:
    /// ```zig
    /// const nwi = @embedFile("icon.nwi");
    /// const meta: eadk.Metadata = .{ .name "My App", .icon = nwi };
    ///
    /// // Include this to make sure it doesn't get optimized away
    /// comptime {
    ///     _ = .{meta.name, meta.api_level, meta.icon};
    /// }
    /// ```
    pub fn set(comptime self: MetaData) type {
        comptime {
            const name_array: [self.name.len:0]u8 = self.name[0..self.name.len :0].*;
            const array_icon: [self.icon.len]u8 = self.icon[0..self.icon.len].*;

            return struct {
                pub export const name: [name_array.len:0]u8 linksection(".rodata.eadk_app_name") = name_array;
                pub export const api_level: u32 linksection(".rodata.eadk_api_level") = self.api_level;
                pub export const icon: [self.icon.len]u8 linksection(".rodata.eadk_app_icon") =
                    array_icon;
            };
        }
    }
};
