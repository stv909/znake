// raylib-zig (c) Nikolas Wipper 2020-2024

const std = @import("std");
const builtin = @import("builtin");

const emccOutputDir = "zig-out" ++ std.fs.path.sep_str ++ "htmlout" ++ std.fs.path.sep_str;
const emccOutputFile = "index.html";
pub fn emscriptenRunStep(b: *std.Build) !*std.Build.Step.Run {
    // If compiling on windows , use emrun.bat.
    const emrunExe = switch (builtin.os.tag) {
        .windows => "emrun.bat",
        else => "emrun",
    };

    const emrun_run_arg = if (b.sysroot) |sysroot| blk: {
        break :blk try std.fs.path.join(b.allocator, &.{ sysroot, emrunExe });
    } else blk: {
        break :blk try b.allocator.dupe(u8, emrunExe);
    };
    defer b.allocator.free(emrun_run_arg);

    const run_cmd = b.addSystemCommand(&[_][]const u8{ emrun_run_arg, emccOutputDir ++ emccOutputFile });
    return run_cmd;
}

// Creates the static library to build a project for Emscripten.
pub fn compileForEmscripten(
    b: *std.Build,
    name: []const u8,
    root_module: *std.Build.Module,
) !*std.Build.Step.Compile {
    // TODO: It might be a good idea to create a custom compile step, that does
    // both the compile to static library and the link with emcc by overidding
    // the make function of the step. However it might also be a bad idea since
    // it messes with the build system itself.

    // The project is built as a library and linked later.
    const lib = b.addLibrary(.{
        .name = name,
        .root_module = root_module,
    });

    const emscripten_headers = try std.fs.path.join(b.allocator, &.{ b.sysroot.?, "cache", "sysroot", "include" });
    defer b.allocator.free(emscripten_headers);
    lib.root_module.addIncludePath(.{ .cwd_relative = emscripten_headers });
    return lib;
}

// Links a set of items together using emscripten.
//
// Will accept objects and static libraries as items to link. As for files to
// include, it is recomended to have a single resources directory and just pass
// the entire directory instead of passing every file individually. The entire
// path given will be the path to read the file within the program. So, if
// "resources/image.png" is passed, your program will use "resources/image.png"
// as the path to load the file.
//
// TODO: Test if shared libraries are accepted, I don't remember if emcc can
//       link a shared library with a project or not.
// TODO: Add a parameter that allows a custom output directory.
pub fn linkWithEmscripten(
    b: *std.Build,
    itemsToLink: []const *std.Build.Step.Compile,
) !*std.Build.Step.Run {
    const emccExe = switch (builtin.os.tag) {
        .windows => "emcc.bat",
        else => "emcc",
    };

    const emcc_run_arg = if (b.sysroot) |sysroot| blk: {
        break :blk try std.fs.path.join(b.allocator, &.{ sysroot, emccExe });
    } else blk: {
        break :blk try b.allocator.dupe(u8, emccExe);
    };
    defer b.allocator.free(emcc_run_arg);

    // Create the output directory because emcc can't do it.
    const mkdir_command = switch (builtin.os.tag) {
        .windows => b.addSystemCommand(&.{ "cmd.exe", "/c", "if", "not", "exist", emccOutputDir, "mkdir", emccOutputDir }),
        else => b.addSystemCommand(&.{ "mkdir", "-p", emccOutputDir }),
    };

    // Actually link everything together.
    const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_run_arg});

    for (itemsToLink) |item| {
        emcc_command.addFileArg(item.getEmittedBin());
        emcc_command.step.dependOn(&item.step);
    }
    // This puts the file in zig-out/htmlout/index.html.
    emcc_command.step.dependOn(&mkdir_command.step);
    emcc_command.addArgs(&[_][]const u8{
        "-o",
        emccOutputDir ++ emccOutputFile,
        "-sUSE_OFFSET_CONVERTER",
        "-sFULL-ES3=1",
        "-sUSE_GLFW=3",
        "-sASYNCIFY",
        "-O3",
        "--emrun",
    });
    return emcc_command;
}

// TODO: See if zig's standard library already has somehing like this.
fn lastIndexOf(string: []const u8, character: u8) usize {
    // Interestingly, Zig has no nice way of iterating a slice backwards.
    for (0..string.len) |i| {
        const index = string.len - i - 1;
        if (string[index] == character) return index;
    }
    return string.len - 1;
}
