const std = @import("std");

var rand: std.Random = undefined;

pub fn run(init: std.process.Init) !void {
    // Initialize your deterministic PRNG with the seed
    const timestamp = std.Io.Clock.now(.real, init.io);
    const seconds = std.Io.Timestamp.toSeconds(timestamp);
    const seed: u64 = @as(u64, @intCast(seconds));
    var prng = std.Random.DefaultPrng.init(seed);
    rand = prng.random();

    std.debug.print("rand {d}\n", .{rand.intRangeAtMost(u16, 0, 100)});
}
