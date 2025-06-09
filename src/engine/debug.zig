const std = @import("std");
const app = @import("app");

extern fn wasmConsoleLog (ptr: u32, len: u32) void;

// const allocator = std.heap.wasm_allocator;

// var log_wasm_buffer: []u8 = undefined;
// var log_wasm_buffer: [1024]u8 = undefined; // check if this affects build size on non wasm platforms

var timer: std.time.Timer = undefined;

pub fn init () void
{
    // log_wasm_buffer = allocator.alloc(u8, 1024) catch return;
}

pub fn log (comptime format: []const u8, args: anytype) void
{
    switch (comptime app.platform)
    {
        .web =>
        {
            // stack allocated buffer
            // var log_wasm_buffer: [format.len]u8 = undefined;

            // heap allocated locally
            // const log_wasm_buffer = allocator.alloc(u8, format.len) catch { return; };

            const message = std.fmt.comptimePrint(format, args);
            // std.fmt.allocPrint(allocator: mem.Allocator, comptime fmt: []const u8, args: anytype)
            // const message = std.fmt.bufPrint(&log_wasm_buffer, format, args) catch return;
            // const ptr = @intFromPtr(&log_wasm_buffer[0]);
            const ptr = @intFromPtr(message);
            const len = message.len;
            wasmConsoleLog(ptr, len);

            // defer allocator.free(log_wasm_buffer);
        },
        .mac, .windows, .linux, .ios, .android =>
        {
            std.log.debug(format, args); // emited in release, adds "debug: " and a newline
            // std.debug.print(format, args); // kept in release, no newline
        },
        else => {}
    }
}

pub fn startTimer () void
{
    timer = std.time.Timer.start() catch unreachable;
}

pub fn printTimer () void
{
    const elapsed_ns = timer.read();
    const microseconds = elapsed_ns / 1000;
    const milliseconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    log("{0} µs, {1d:.3} ms", .{ microseconds, milliseconds });
}