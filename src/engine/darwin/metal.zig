const std = @import("std");
const app = @import("app");
const math = @import("math");
const debug = @import("debug");
const graphics = @import("graphics");

extern fn createLibraryFromData_metal (data_ptr: [*]const u8, data_len: usize) ?*anyopaque;
extern fn createFunction_metal (name: [*:0]const u8, library: ?*anyopaque) ?*anyopaque;
extern fn createPipelineVertFrag_metal (name: [*:0]const u8, vert: ?*anyopaque, frag: ?*anyopaque) ?*anyopaque;

pub const Material = struct
{
    active_mtl_pipeline: *anyopaque = 0,
    pipeline: *Pipelines, // only invoked when keywords or blending changes, so no cache misses most of the time

    // uniforms

    // pub fn setVertKeywords (self: Material, const[] const[] u8 keywords) void
    // {
    // }

    // pub fn setFragKeywords (self: Material, const[] const[] u8 keywords) void
    // {
    // }
};

const Metal = struct
{
    allocator: std.mem.Allocator = undefined,

    mtl_function_idx_counter: usize = 0,

    libraries: std.AutoHashMap(usize, *anyopaque) = undefined, // k: library_group
    functions: std.AutoHashMap(usize, Functions) = undefined, // k: FunctionParam hash
    pipelines: std.AutoHashMap(usize, Pipelines) = undefined, // k: Pipelines hash
};

var metal: Metal = .{};

pub fn init (allocator: std.mem.Allocator) void
{
    metal.allocator = allocator;

    metal.libraries = std.AutoHashMap(usize, *anyopaque).init(allocator);
    metal.functions = std.AutoHashMap(usize, Functions).init(allocator);
    metal.pipelines = std.AutoHashMap(usize, Pipelines).init(allocator);
}

pub fn createLibraryGroup (comptime name: []const u8) usize
{
    // TODO is it too much of comptime?
    return comptime math.perfectHash(name);
}

pub fn createLibrary (data: []const u8, library_group: usize) void
{
    const library = createLibraryFromData_metal(data.ptr, data.len);
    const vert = createFunction_metal("vertexShader", library);
    const frag = createFunction_metal("fragmentShader", library);
    _ = createPipelineVertFrag_metal("Simple Pipeline", vert, frag);

    if (library) |lib|
    {
        metal.libraries.put(library_group, lib) catch unreachable;
    }
}

pub fn initMaterial (vert: graphics.FunctionParam, frag: graphics.FunctionParam) Material
{
    _ = vert;
    _ = frag;

    // return .{ .pipeline =  };
}

fn getPipelines (vert_param: graphics.FunctionParam, frag_param: graphics.FunctionParam) ?*Pipelines
{
    const vert = getFunctions(vert_param) orelse return null;
    const frag = getFunctions(frag_param) orelse return null;

    putMTLFunction(vert.?, vert_param);
    putMTLFunction(frag.?, frag_param);

    const hash = Pipelines.getHash(vert.?.unique_idx, frag.?.unique_idx);
    var pipelines = metal.pipelines.get(hash);
    if (pipelines == null)
    {
        pipelines = Pipelines.new(metal.allocator, vert.?, frag.?);
        metal.pipelines.put(hash, pipelines);
    }
    return pipelines;
}

fn getFunctions (param: graphics.FunctionParam) ?*Functions
{
    var functions = metal.functions.get(param.hash);
    if (functions == null)
    {
        functions = Functions.new(metal.allocator);
        metal.functions.put(param.hash, functions);
    }
    return functions;
}

fn putMTLFunction (self: *Functions, param: graphics.FunctionParam) void
{
    const library = getLibrary(param.library_group) orelse return;

    const has_mtlfunction = self.mtl_functions.contains(param.function_name);
    if (!has_mtlfunction)
    {
        const mtlfunction = createFunction_metal(param.function_name, library) orelse return;
        self.mtl_functions.put(param.name_hash, mtlfunction);
    }
}

fn getLibrary (param: graphics.FunctionParam) ?*anyopaque
{
    const library = metal.libraries.get(param.library_group);
    return library;
}

const Pipelines = struct
{
    vert: *Functions,
    frag: *Functions,
    // compute: *ComputeFunction,
    // blending, etc...
    mtl_pipelines: std.AutoHashMap(usize, *anyopaque), // hash computed to identify unique mtl_pipeline from keywords + blending

    pub fn new (allocator: std.mem.Allocator, vert: *Functions, frag: *Functions) Pipelines
    {
        return .{
            .vert = vert,
            .frag = frag,
            .mtl_pipelines = std.AutoHashMap(usize, *anyopaque).init(allocator),
        };
    }

    pub fn getHash (vert_idx: usize, frag_idx: usize) usize
    {
        return vert_idx * 100_000 + frag_idx;
    }
};

// MTLFunction with all its keywords combination
const Functions = struct
{
    unique_idx: usize,
    mtl_functions: std.AutoHashMap(usize, *anyopaque),

    pub fn new (allocator: std.mem.Allocator) Functions
    {
        metal.mtl_function_idx_counter += 1;

        return .{
            .unique_idx = metal.mtl_function_idx_counter,
            .mtl_functions = std.AutoHashMap(usize, *anyopaque).init(allocator),
        };
    }
};