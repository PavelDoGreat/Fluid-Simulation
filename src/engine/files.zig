const std = @import("std");
const app = @import("app");
const debug = @import("debug");
const memory = @import("memory");

pub var exe_path: []const u8 = undefined;

var exe_path_buffer: [1024]u8 = undefined; // TODO test if it affects wasm build size;

const max_file_size = memory.megabytesToBytes(3);

pub fn init () !void
{
    if (comptime app.platform.supportFileSystem())
    {
        exe_path = try std.fs.selfExeDirPath(&exe_path_buffer);
    }
}

pub fn loadFile (allocator: std.mem.Allocator, fileName: []const u8) !?[]const u8
{
    // []const u8 is a string
    // [_] array with '_' size which is replaced for number 2
    const file_path = try std.fs.path.join(allocator, &.{ exe_path, fileName }); // &[_][]const u8  // TODO how to make it stack allocated?
    defer allocator.free(file_path);
    // debug.log("path: {s}", .{ file_path });
    const file = std.fs.openFileAbsolute(file_path, .{}) catch |err| switch (err)
    {
        error.FileNotFound =>
        {
            debug.log("File not found: {s}", .{ file_path });
            return null; //allocator.alloc(u8, 0); // allocator.dupe(u8, &[1]u8{0}) // &[0]u8{}
        },
        else => return err,
    };
    defer file.close();

    const buffer = try file.readToEndAlloc(allocator, max_file_size);
    // const bytes_read = try file.reader().readAll(buf: []u8)
    return buffer;
}

// const dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
// var it = dir.iterate();
// while (try it.next()) |file|
//     debug.log("{s}", . { file.name });

// const exe_path = try std.fs.selfExeDirPath(&text_buffer);
// debug.log("{s}", .{ exe_path });




// For the future: it is possible to embed file into binary at comptime
// const data = @embedFile("calories.txt");
// const split = std.mem.split;

// pub fn main() !void {
//     var splits = split(u8, data, "\n");
//     while (splits.next()) |line| {
//         std.debug.print("{s}\n", .{line});
//     }
// }