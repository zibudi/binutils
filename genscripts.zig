//! Runs upstream's genscripts.sh, which writes into the current directory

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    if (args.len != 5) {
        std.debug.print("usage: {s} <output_dir> <ld_source_dir> <emulations> <triple>\n", .{args[0]});
        std.process.exit(1);
    }

    const out = args[1];
    const source = try std.Io.Dir.cwd().realPathFileAlloc(io, args[2], arena);
    const emulations = args[3];
    const triple = args[4];

    try std.Io.Dir.cwd().createDirPath(io, try std.fmt.allocPrint(arena, "{s}/ldscripts", .{out}));

    var it = std.mem.tokenizeScalar(u8, emulations, ' ');
    while (it.next()) |emulation| {
        var child = try std.process.spawn(io, .{
            .cwd = .{ .path = out },
            .argv = &.{
                "sh",
                try std.fmt.allocPrint(arena, "{s}/genscripts.sh", .{source}),
                source,
                "/usr/lib",
                "/usr",
                "/usr",
                triple,
                triple,
                triple,
                "",
                "",
                emulations,
                "",
                "no",
                "yes",
                emulation,
                triple,
            },
        });
        switch (try child.wait(io)) {
            .exited => |code| if (code != 0) return error.GenscriptsFailed,
            else => return error.GenscriptsFailed,
        }
    }
}
