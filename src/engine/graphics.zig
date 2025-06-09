const std = @import("std");
const app = @import("app");
const math = @import("math");
const debug = @import("debug");
const metal = @import("darwin/metal.zig");

pub fn init () void
{
    const allocator = std.heap.c_allocator;

    if (comptime app.graphics_api == .metal)
    {
        metal.init(allocator);
    }
}

// Combines multiple libraries and shader files under 1 id. No duplicate function names allowed.
pub fn createLibraryGroup (comptime name: []const u8) usize
{
    if (comptime app.graphics_api == .metal)
    {
        return metal.createLibraryGroup(name);
    }

    debug.log("No platform for createLibraryGroup: {s}", .{ @tagName(app.platform) });
    return 0;
}

pub fn createLibrary (data: []const u8, library_group: usize) void
{
    if (comptime app.graphics_api == .metal)
    {
        metal.createLibrary(data, library_group);
    }
}

pub fn blit () void
{
    // switch (comptime app.graphicsAPI)
    // {
    //     .metal => init_and_open_window_osx(),
    //     else   => {},
    // }
}

// material is 1 vert + 1 frag + keywords + blending + uniforms
// TODO union with platform's implementation of Material
pub const Material = struct
{
    internal: metal.Material,
    vert: FunctionParam,
    frag: FunctionParam,

    pub fn new (vert: FunctionParam, frag: FunctionParam) Material
    {
        return .{ .vert = vert, .frag = frag };
    }

    pub fn init (self: Material) void
    {
        if (comptime app.graphics_api == .metal)
        {
            self.internal = metal.initMaterial(self.vert, self.frag);
        }
    }
};

const FunctionParam = struct
{
    hash: usize,
    name_hash: usize,
    function_name: []const u8,
    library_group: usize,

    pub fn new (comptime function_name: []const u8, comptime library_group: usize) FunctionParam
    {
        const name_hash = comptime math.perfectHash(function_name);
        var hash = name_hash & 0x03FFFFFF;
        hash |= (@as(u32, library_group) << 26); // TODO do I need cast?

        return .{ .hash = hash, .name_hash = name_hash, .function_name = function_name, .library_group = library_group };
    }
};

pub const RenderTarget = struct
{
    // var static_var: sometype = .{};

    // member_var: sometype = .{};
};

pub const DoubleRenderTarget = struct
{
    // var static_var: sometype = .{};

    // member_var: sometype = .{};
};

// &[_]f32{ -1, -1, -1, 1, 1, 1, 1, -1 }
// &[_]u16{ 0, 1, 2, 0, 2, 3 }