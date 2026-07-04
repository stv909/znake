const std = @import("std");
const game = @import("game2d.zig");

pub fn main(init: std.process.Init) !void {
    try game.run(init);
}
