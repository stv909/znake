const std = @import("std");
const game = @import("root.zig");

pub fn main(init: std.process.Init) !void {
    try game.run(init);
}
