const std = @import("std");
const app = @import("app");
const debug = @import("debug");
const files = @import("files");
const graphics = @import("graphics");
const materials = @import("materials");

// TODO async file loading
// TODO arena allocator
pub fn load () void
{
    // var buffer: [10000]u8 = undefined;
    // var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    // const allocator = fixed.allocator();//std.heap.FixedBufferAllocator.init(&buffer);
    // defer allocator
// std.ArrayList(u32).init(allocator: Allocator)

    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();

    // const allocator = arena.allocator();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // gpa.deinit(self: *Self)
    // std.heap.ArenaAllocator

    debug.startTimer();

    if (comptime app.graphics_api == .metal)
    {
        loadShaderFile(allocator, "shader.metallib", materials.fluid_group);
    }

    debug.printTimer();
}

fn loadShaderFile (allocator: std.mem.Allocator, shaderName: []const u8, library_group: usize) void
{
    const buffer = files.loadFile(allocator, shaderName) catch unreachable;

    if (buffer) |buf|
    {
        graphics.createLibrary(buf, library_group);
        allocator.free(buf);
    }
}