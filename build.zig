const std = @import("std");
const Build = std.Build;

// TODO move hardcore parts to a separate /src/build.zig

/// Command to run debug
//~ zig build run

/// Command to run optimized build
//~ zig build --release=fast run

/// You can add --watch to always build on code changes. Very convenient btw.

/// This is for building web version
//~ zig build -Dtarget=wasm32-freestanding -p projects/web --watch
/// Then run local server and open in web browser http://localhost:1369/
//~ python3 -m http.server 1369 --directory projects/web

/// Just left over for the future
// --release=small --release=safe  wasm32-freestanding wasm32-wasi wasm32-emscripten
// --verbose

const engine = [_]NameAndModulePath {
    .{ .name = "app", .path = "src/engine/application.zig" },
    .{ .name = "native", .path = "src/engine/native.zig" },
    .{ .name = "debug", .path = "src/engine/debug.zig" },
    .{ .name = "files", .path = "src/engine/files.zig" },
    .{ .name = "math", .path = "src/engine/math.zig" },
    .{ .name = "memory", .path = "src/engine/memory.zig" },
    .{ .name = "graphics", .path = "src/engine/graphics.zig" },
};

const fluid = [_]NameAndModulePath {
    .{ .name = "materials", .path = "src/fluid/materials.zig" },
};

pub fn build (b: *Build) !void
{
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const target = b.resolveTargetQuery(.{ .os_tag = .macos });

    const imports = engine ++ fluid;

    if (target.result.cpu.arch.isWasm())
    {
        const exe = b.addExecutable(.{
            .name = "fluid",
            .target = target,
            .optimize = .ReleaseSmall, // .Debug .ReleaseFast
            .root_source_file = b.path("src/fluid/main.zig"),
        });
        exe.entry = .disabled;
        exe.rdynamic = true;

        // exe.root_module.export_symbol_names

        addImports(b, exe.root_module, &imports);
        b.installArtifact(exe);
    }
    else if (target.result.os.tag == .macos)
    {
        // try std.fs.cwd().makePath("zig-out/lib/");

        const exe = b.addExecutable(.{
            .name = "fluid",
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/fluid/main.zig"),
            // .root_module = exe_mod,
            // .single_threaded = true,
            // .strip = true,
            // .omit_frame_pointer = false,
            // .unwind_tables = .none,
            // .error_tracing = false
        });
        // exe.entry = .{ .symbol_name = "init" };
        // exe.entry = .disabled;
        // exe.addArg("-mmacos-version-min=11.0"); // sets minimum macos version

        // const exe_lib = b.addStaticLibrary(.{
        //     .name = "fluid",
        //     .target = target,
        //     .optimize = optimize,
        //     .root_source_file = b.path("src/fluid/main.zig"),
        // });
        // exe_lib.entry = .disabled;

        // addCommonImports(b, exe.root_module);
        addImports(b, exe.root_module, &imports);
        addLibrariesOSX(b, target, exe);

        // TODO come back to it when new Zig version will release
        // _ = exe.getEmittedH();
        // exe.addCSourceFile(.{});

        const metal = addCompileMetal(b);

        compileSwift(b, optimize, exe);
        const installexe = b.addInstallArtifact(exe, .{});

        b.default_step.dependOn(&installexe.step);
        b.default_step.dependOn(&metal.step);

        const run = b.addRunArtifact(exe);
        run.step.dependOn(b.getInstallStep());
        b.step("run", "Run the app").dependOn(&run.step);
    }
}

// TODO remove
// fn addCommonImports (b: *Build, root_module: *Build.Module) void
// {
//     const app = b.createModule(.{ .root_source_file = b.path("src/engine/application.zig") });
//     const native = b.createModule(.{ .root_source_file = b.path("src/engine/native.zig") });
//     const debug = b.createModule(.{ .root_source_file = b.path("src/engine/debug.zig") });
//     const files = b.createModule(.{ .root_source_file = b.path("src/engine/files.zig") });
//     const math = b.createModule(.{ .root_source_file = b.path("src/engine/math.zig") });
//     const graphics = b.createModule(.{ .root_source_file = b.path("src/engine/graphics.zig") });

//     importModulesToEachOtherAndToRoot(root_module, &.{
//         .{ .name = "app", .module = app },
//         .{ .name = "native", .module = native },
//         .{ .name = "debug", .module = debug },
//         .{ .name = "files", .module = files },
//         .{ .name = "math", .module = math },
//         .{ .name = "graphics", .module = graphics },
//     });

//     // module.addAnonymousImport("utils", "src/utils.zig");
// }

fn addCompileMetal (b: *Build) *Build.Step.Run
{
    const metalir = b.addSystemCommand(&.{
        "xcrun", "-sdk", "macosx", "metal",
    });
    metalir.addArg("-c");
    metalir.addFileArg(b.path("src/fluid/shaders/shader.metal"));
    const output_ir = metalir.addPrefixedOutputFileArg("-o", "shader.ir");

    const metallib = b.addSystemCommand(&.{
        "xcrun", "-sdk", "macosx", "metallib",
        "-o", "zig-out/bin/shader.metallib",
    });
    metallib.addFileArg(output_ir);
    // metallib.addFileInput()

    // metallib.addCheck(.{ .expect_term = .{ .Exited = 0 } }); // no idea what it is
    // metallib.has_side_effects = true; // forces to rebuild every time

    return metallib;
}

fn compileSwift (b: *Build, optimize: std.builtin.OptimizeMode, exe: *Build.Step.Compile) void
{
    // const objc = b.addSystemCommand(&.{
    //     "clang",
    //     // "-O3",
    //     "-o", "zig-out/lib/cocoa_osx.o",
    //     "-c", "src/engine/darwin/cocoa_osx.mm",
    // });

    const swift = b.addSystemCommand(&.{
        "xcrun", "swiftc",
        "-emit-object",
        // "-emit-library", // this one also exports _main and use linker magic
        "-static", // does it work?
        "-parse-as-library", // removes _main
        "-whole-module-optimization",
        // "-I", "src/engine/darwin/",

        // enables useful compilation warnings
        // -warn-swift3-objc-inference-complete
        // -warn-concurrency -enable-actor-data-race-checks

        // to test if code compiles for older os versions
        // "-target", "arm64-apple-macos11.0",

        // for the future
        // "-target-cpu"
        // "-target",
        // b.fmt("{s}-apple-macosx{}", .{
        //     @tagName(target.result.cpu.arch),
        //     target.result.os.version_range.semver.min,
        // }),

        // "-sanitize=address",

        if (optimize == .Debug) "-Onone" else "-O",
    });
    if (optimize == .Debug) swift.addArgs(&.{ "-D", "DEBUG", "-g" });

    // swift.addArg("-I");
    // swift.addDirectoryArg(b.path("src/engine/darwin/"));
    swift.addPrefixedDirectoryArg("-I", b.path("src/engine/darwin/"));

    // zig automatically detects if file has been changed to run swift step
    swift.addFileArg(b.path("src/engine/darwin/cocoa_osx.swift"));
    swift.addFileArg(b.path("src/engine/darwin/metal.swift"));

    // this adds dependency to exe step
    exe.addObjectFile(swift.addPrefixedOutputFileArg("-o", "cocoa_osx.o"));
}

// TODO it is a better idea to auto add dependencies after swift step
// if of course Apple have made it easy
fn addLibrariesOSX (b: *Build, target: Build.ResolvedTarget, exe: *Build.Step.Compile) void
{
    //~ xcrun --show-sdk-path
    const sdk = std.zig.system.darwin.getSdk(b.allocator, target.result).?;
    // std.log.debug("{s}", .{ sdk.? });

    // obj-c libraries
    // exe.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/usr/include/", .{sdk}) });
    // exe.addFrameworkPath(.{ .cwd_relative = b.fmt("{s}/System/Library/Frameworks/", .{sdk}) });
    // exe.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/usr/lib/", .{sdk}) });

    // swift libraries
    exe.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/usr/lib/swift/", .{sdk}) });
    // exe.addRPath(.{ .cwd_relative = b.fmt("{s}/usr/lib/swift/", .{sdk}) }); // what the hell is RPath?

    // exe.linkLibC();
    // exe.linkLibCpp();

    exe.linkFramework("Foundation");
    exe.linkFramework("Cocoa");
    exe.linkFramework("Metal");
    exe.linkFramework("QuartzCore");

    // force static linking, can be useful in a future
    // exe.addObjectFile(.{ .cwd_relative = b.fmt("{s}/usr/lib/swift_static/macosx/libswiftCore.a", .{sdk}) });
    // or bundle swift runtime when releasing
    // TODO

    // shows system libraries that library use
    //~ nm -u zig-out/lib/cocoa_osx.o | grep swift

    // show all dynamically linked libraries of exe
    //~ otool -L zig-out/bin/fluid

    // shows runtime search paths of exe
    //~ otool -l zig-out/bin/fluid | grep -A2 LC_RPATH

    exe.linkSystemLibrary("swiftCore");
    exe.linkSystemLibrary("swiftFoundation");
    exe.linkSystemLibrary("swift_Concurrency");
    exe.linkSystemLibrary("swiftDispatch");
    exe.linkSystemLibrary("swiftObjectiveC");
    exe.linkSystemLibrary("swiftCoreGraphics");
    exe.linkSystemLibrary("swiftMetal");
    exe.linkSystemLibrary("swiftQuartzCore");
    exe.linkSystemLibrary("swiftIOKit");
    exe.linkSystemLibrary("swiftXPC");
    exe.linkSystemLibrary("swiftos");
    exe.linkSystemLibrary("swiftCoreFoundation");
    exe.linkSystemLibrary("swiftCoreImage");
    exe.linkSystemLibrary("swiftDarwin");
    exe.linkSystemLibrary("swiftUniformTypeIdentifiers");

    // 
    exe.linkSystemLibrary("swiftDataDetection");
    exe.linkSystemLibrary("swiftOSLog");
}

const NameAndModulePath = struct
{
    name: []const u8,
    path: []const u8,
};

const NameAndModule = struct
{
    name: []const u8,
    module: *Build.Module,
};

fn addImports (b: *Build, root_module: *Build.Module, comptime modules_desc: []const NameAndModulePath) void
{
    var modules: [modules_desc.len]NameAndModule = undefined;

    for (modules_desc, 0..) |desc, i|
    {
        modules[i] = .{
            .name = desc.name,
            .module = b.createModule(.{ .root_source_file = b.path(desc.path) }),
        };
    }

    importModulesToEachOtherAndToRoot(root_module, &modules);
}

fn importModulesToEachOtherAndToRoot (root_module: *Build.Module, modules: []const NameAndModule) void
{
    for (modules) |group|
    {
        for (modules) |tuple|
        {
            if (group.module != tuple.module)
                group.module.addImport(tuple.name, tuple.module);
        }
    }

    for (modules) |tuple|
        root_module.addImport(tuple.name, tuple.module);
}

// // TODO do I really need this?
// fn sequence (b: *Build, steps: []const *Build.Step) void
// {
//     if (steps.len == 0) return;
//     if (steps.len == 1)
//     {
//         b.default_step.dependOn(steps[0]);
//         return;
//     }

//     for (steps[1..], 0..) |step, i|
//     {
//         step.dependOn(steps[i]);
//     }
//     b.default_step.dependOn(steps[steps.len - 1]);
// }



// const exe_check = b.addExecutable(.{
//     .name = "fluid",
//     .root_source_file = b.path("src/main.zig"),
// });

// const check = b.step("check", "Check if fluid compiles");
// check.dependOn(&exe_check.step);