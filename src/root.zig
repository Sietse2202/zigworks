//! Zig bindings for the [NumWorks](https://github.com/numworks/epsilon) SDK

/// The C header that the library wraps
pub const eadk_internal = @import("eadk_internal.zig");
pub const extppp_internal = @import("extapp_internal.zig");
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

pub const storage = struct {
    pub fn doesFileExist(name: []const u8) bool {
        return extppp_internal.extapp_fileExists(name.ptr);
    }

    pub fn listFiles(filenames: [][]const u8, max_count: u16) error{InvalidStorage}!void {
        const file_count = extppp_internal.extapp_fileList(filenames.ptr, @intCast(max_count), "");
        if (file_count == -1)
            return error.InvalidStorage;
    }

    pub fn listFilesWithExtension(
        buffer: [][*c]const u8,
        extension: [:0]const u8,
    ) error{ InvalidResult, BufferTooSmall }![][:0]const u8 {
        if (buffer.len == 0) return &.{};
        if (buffer.len > std.math.maxInt(c_int)) return error.BufferTooSmall;

        const count = extppp_internal.extapp_fileListWithExtension(
            buffer.ptr,
            @intCast(buffer.len),
            extension.ptr,
        );

        if (count < 0) return error.InvalidResult;
        const file_count: usize = @intCast(count);
        if (file_count > buffer.len) return error.InvalidResult;

        var result: [buffer.len][:0]const u8 = undefined;
        for (buffer[0..file_count], 0..) |c_str, i| {
            if (c_str) |ptr| {
                result[i] = std.mem.span(ptr);
            } else {
                return error.InvalidResult;
            }
        }

        return result[0..file_count];
    }

    pub fn readFile(filename: []const u8) error{ReadFile}![]const u8 {
        var len: usize = filename.len;
        const ptr: [*]const u8 = extppp_internal.extapp_fileRead(filename.ptr, &len);
        if (ptr == null)
            return error.ReadFile;

        return ptr[0..len];
    }

    pub fn writeToFile(filename: []const u8, content: []const u8) error{WriteFile}!void {
        if (!extppp_internal.extapp_fileWrite(filename, content.ptr, content.len))
            return error.WriteFile;
    }
};

/// Experimental and not yet tested.
pub const external_data: []const u8 = eadk_internal.eadk_external_data[0..eadk_internal.eadk_external_data_size];

pub const random = struct {
    /// Generate a random unsigned integer, `T` can be any `u<n>`, where n ∈ [1, 32]
    pub fn randomInt(comptime T: type) T {
        const type_info = @typeInfo(T);
        if (type_info != .int or type_info.int.signedness != .unsigned) {
            @compileError("randomInt only supports unsigned integer types");
        }

        const bits = @bitSizeOf(T);
        if (bits > 32) {
            @compileError("randomInt only supports types up to 32 bits");
        }

        if (bits == 32) {
            return eadk_internal.eadk_random();
        }

        const raw = eadk_internal.eadk_random();
        return @truncate(raw >> (32 - bits));
    }

    /// Same constraints as `randomInt` except it is bound to a certain range,
    /// this function aims to retain the distribution of the original
    pub fn randomInRange(comptime T: type, min: T, max: T) T {
        const max_t = @import("std").math.maxInt(T);

        const n = max - min + 1;
        const rem = max_t % n;
        var x = randomInt(T);

        while (x >= max_t - rem) {
            x = randomInt(T);
        }

        return min + x % n;
    }
};

pub const model = struct {
    pub const CalculatorModel = enum(u2) {
        Unknown = 0,
        @"N0110/N0115" = 1,
        N0120 = 2,
    };

    const asU2: u2 = @truncate(extppp_internal.extapp_calculatorModel());
    pub const calculator_model: CalculatorModel = @enumFromInt(asU2);
    pub const userland_address: u32 = extppp_internal.extapp_userlandAddress();
};

pub const MetaData = struct {
    name: [:0]const u8,
    api_level: u32 = 0,
    icon: []const u8,
};

/// Convenience function for setting the required metadata in the final elf, if you don't use the symbols, zig will
/// optimize them away, so be sure to do something like this:
/// ```zig
/// const embed = @embedFile("icon.nwi");
/// const AppMetadata = eadk.setMetadata("Zig App", 0, embed.*);
///
/// // If you don't include this, the data gets optimized away, and your app won't link
/// comptime {
///     _ = AppMetadata.EADK_APP_NAME;
///     _ = AppMetadata.EADK_APP_API_LEVEL;
///     _ = AppMetadata.EADK_APP_ICON;
/// }
/// ```
pub fn setMetadata(
    comptime meta: MetaData,
) type {
    comptime {
        const name_array: [meta.name.len:0]u8 = meta.name[0..meta.name.len :0].*;
        const array_icon: [meta.icon.len]u8 = meta.icon[0..meta.icon.len].*;

        return struct {
            pub export const eadk_app_name: [name_array.len:0]u8 linksection(".rodata.eadk_app_name") = name_array;
            pub export const eadk_app_api_level: u32 linksection(".rodata.eadk_api_level") = meta.api_level;
            pub export const eadk_app_icon: [meta.icon.len]u8 linksection(".rodata.eadk_app_icon") =
                array_icon;
        };
    }
}
