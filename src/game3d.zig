const std = @import("std");
const ray = @import("raylib");

var rand: std.Random = undefined;

pub fn run(init: std.process.Init) !void {
    // Initialize your deterministic PRNG with the seed
    const timestamp = std.Io.Clock.now(.real, init.io);
    const seconds = std.Io.Timestamp.toSeconds(timestamp);
    const seed: u64 = @as(u64, @intCast(seconds));
    var prng = std.Random.DefaultPrng.init(seed);
    rand = prng.random();
    std.debug.print("rand {d}\n", .{rand.intRangeAtMost(u16, 0, 100)});

    const screen_width = 1400;
    const screen_height = 800;

    ray.initWindow(screen_width, screen_height, "znake 3D");
    defer ray.closeWindow();

    // Orbital camera: starts above and to the side, looking at the cube
    var camera = ray.Camera3D{
        .position = .{ .x = 6.0, .y = 5.0, .z = 6.0 },
        .target = .{ .x = 0.0, .y = 0.5, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = .perspective,
    };

    ray.disableCursor();
    ray.setTargetFPS(60);

    while (!ray.windowShouldClose()) {
        // Update camera: right-click + drag to orbit, scroll to zoom
        camera.update(.orbital);

        ray.beginDrawing();
        defer ray.endDrawing();

        ray.clearBackground(ray.getColor(0x1A1A2EFF)); // Dark navy

        camera.begin();
        defer camera.end();

        // Ground plane (XZ plane, horizontal)
        ray.drawPlane(
            .{ .x = 0, .y = 0, .z = -0.001 },
            .{ .x = 16, .y = 16 },
            ray.getColor(0x3D3D5CFF),
        );

        // Reference grid on the plane
        ray.drawGrid(16, 1.0);

        // Cube resting on the plane (center at y=0.5, bottom touches y=0)
        ray.drawCube(
            .{ .x = 0, .y = 0.5, .z = 0 },
            1.0,
            1.0,
            1.0,
            ray.getColor(0xFF6B6BFF), // Coral red
        );

        // Wireframe outline for visual definition
        ray.drawCubeWires(
            .{ .x = 0, .y = 0.5, .z = 0 },
            1.0,
            1.0,
            1.0,
            ray.getColor(0x1A1A2EFF),
        );
    }
}
