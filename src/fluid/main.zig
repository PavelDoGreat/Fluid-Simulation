const std = @import("std");
const app = @import("app");
const debug = @import("debug");
const files = @import("files");
const native = @import("native");
const graphics = @import("graphics");

const resources = @import("library/resources.zig");

// If I want to remove _main, I also need to disable _start
// pub const _start = void;
// pub const WinMainCRTStartup = void;

pub fn main () void
{
    // native.startApp(&start);
    native.startApp();
}

export fn start () void
{
    files.init() catch unreachable;

    // debug.log("Platform: {s}", .{ @tagName(app.platform) });
    // debug.log("Exe path: {s}", .{ files.exe_path });

    graphics.init();
    resources.load();

    // wasm build size grows quickly with every log
    // debug.log("hi", .{});
    // debug.log("hii", .{});
    // debug.log("hiii", .{});
}

export fn update () void
{

}

export fn draw () void
{

}


// pub const std_options: std.Options = .{
//     // By default, in safe build modes, the standard library will attach a segfault handler to the program to
//     // print a helpful stack trace if a segmentation fault occurs. Here, we can disable this, or even enable
//     // it in unsafe build modes.
//     .enable_segfault_handler = true,
// };

// pub const panic = std.debug.FullPanic(panic);

// pub fn panic (msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn
// {
//     _ = error_return_trace;
//     // _ = msg;
//     _ = ret_addr;
//     std.debug.print("Panic! {s}\n", .{msg});
//     // std.debug.print("yooo", .{});
//     std.process.exit(1);
// }


// const shd = @import("shaders/fluid.glsl.zig");

// const State = struct
// {
//     var pip: sg.Pipeline = .{}; // shader, attributes
//     var bind: sg.Bindings = .{}; // vertex and index data
//     var pass_action: sg.PassAction = .{}; // global
//     // pass_action: sg.PassAction // local
// };