const std = @import("std");

pub const EpsilonSyscall = enum(u8) {
    authentication_clearance_level = 0,
    backlight_brightness = 1,
    set_backlight_brightness = 2,
    battery_is_charging = 3,
    battery_level = 4,
    battery_voltage = 5,
    board_update_clearance_level_for_external_apps = 6,
    board_update_clearance_level_for_authenticated_userland = 7,
    circuit_breaker_has_checkpoint = 8,
    circuit_breaker_load_checkpoint = 9,
    circuit_breaker_lock = 10,
    circuit_breaker_set_checkpoint = 11,
    circuit_breaker_status = 12,
    circuit_breaker_unlock = 13,
    circuit_breaker_unset_checkpoint = 14,
    crc32_byte = 15,
    crc32_word = 16,
    display_post_push_multicolor = 17,
    display_pull_rect = 18,
    display_push_rect = 19,
    display_push_rect_uniform = 20,
    display_wait_for_vblank = 21,
    events_copy_text = 22,
    events_get_event = 23,
    events_is_defined = 24,
    // Unused 25
    events_set_shift_alpha_status = 26,
    events_set_spinner = 27,
    events_shift_alpha_status = 28,
    fcc_id = 29,
    flash_erase_sector_with_interruptions = 30,
    flash_mass_erase_with_interruptions = 31,
    flash_write_memory_with_interruptions = 32,
    keyboard_pop_state = 33,
    keyboard_scan = 34,
    led_get_color = 35,
    led_set_blinking = 36,
    led_set_color = 37,
    led_update_color_with_plug_and_charge = 38,
    pcb_version = 39,
    // Unused 40
    // Unused 41
    power_select_standby_mode = 42,
    power_standby = 43,
    power_suspend = 44,
    random = 45,
    reset_core = 46,
    serial_number_copy = 47,
    timing_millis = 48,
    timing_msleep = 49,
    timing_usleep = 50,
    usb_did_execute_dfu = 51,
    usb_is_plugged = 52,
    usb_should_interrupt = 53,
    usb_will_execute_dfu = 54,
    events_long_press_counter = 55,
    compilation_flags = 56,
    bootloader_crc32 = 57,
    led_set_lock = 58,
    reset_last_reset_type = 59,
    _,

    pub inline fn toAsm(comptime syscall: EpsilonSyscall) []const u8 {
        return std.fmt.comptimePrint("svc #{d}", .{@intFromEnum(syscall)});
    }
};

pub inline fn svc0(comptime syscall: EpsilonSyscall) void {
    asm volatile (syscall.toAsm());
}

pub inline fn svc0r(comptime syscall: EpsilonSyscall) u32 {
    return asm volatile (syscall.toAsm()
        : [ret] "={r0}" (-> u32),
        :
        : .{ .r0 = true });
}

pub inline fn svc1(comptime syscall: EpsilonSyscall, a: u32) void {
    asm volatile (syscall.toAsm()
        :
        : [a] "{r0}" (a),
    );
}

pub inline fn svc1r(comptime syscall: EpsilonSyscall, a: u32) u32 {
    return asm volatile (syscall.toAsm()
        : [ret] "={r0}" (-> u32),
        : [a] "{r0}" (a),
        : .{ .r0 = true });
}

pub inline fn svc2(comptime syscall: EpsilonSyscall, a: u32, b: u32) void {
    asm volatile (syscall.toAsm()
        :
        : [a] "{r0}" (a),
          [b] "{r1}" (b),
    );
}

pub inline fn svc3(comptime syscall: EpsilonSyscall, a: u32, b: u32, c: u32) void {
    asm volatile (syscall.toAsm()
        :
        : [a] "{r0}" (a),
          [b] "{r1}" (b),
          [c] "{r2}" (c),
    );
}

pub inline fn svc0r64(comptime syscall: EpsilonSyscall) u64 {
    return asm volatile (syscall.toAsm()
        : [ret] "=r" (-> u64),
        :
        : .{ .r0 = true, .r1 = true });
}

pub inline fn svc0s(comptime syscall: EpsilonSyscall) f32 {
    return asm volatile (syscall.toAsm()
        : [ret] "={s0}" (-> f32),
        :
        : .{ .s0 = true });
}
