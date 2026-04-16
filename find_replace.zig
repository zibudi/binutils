//! This is used as a replacement for `sed`

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len != 5) {
        std.debug.print("usage: {s} <input_file> <output_file> <before> <after>\n", .{args[0]});
        std.process.exit(1);
    }

    const input_filename = args[1];
    const output_filename = args[2];
    const before = args[3];
    const after = args[4];

    const input = try cwd.readFileAlloc(io, input_filename, gpa, .limited(std.math.maxInt(u32)));
    defer gpa.free(input);

    const output = try std.mem.replaceOwned(u8, gpa, input, before, after);
    defer gpa.free(output);

    try cwd.writeFile(io, .{
        .sub_path = output_filename,
        .data = output,
    });
}
