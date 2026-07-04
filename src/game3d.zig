const std = @import("std");
const ray = @import("raylib");

var rand: std.Random = undefined;

const BACK_COLOR = 0x404040FF;
const BOARD_COLOR = 0x2E2E2EFF; // Jet Black
const SNAKE_COLOR = 0x81D4FAFF; // Light Blue Pastel
//const FOOD_COLOR = 0xFFCDD2FF; // Soft Coral

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

    var angle_horizontal: f32 = 45.0; // degrees, azimuth
    var angle_vertical: f32 = 45.0; // degrees, elevation
    var distance: f32 = 10.0;
    const target = ray.Vector3{ .x = 0, .y = 0.5, .z = 0 };

    while (!ray.windowShouldClose()) {
        // Mouse orbital control: move to orbit, scroll to zoom
        {
            const delta = ray.getMouseDelta();
            angle_horizontal -= delta.x * 0.3;
            angle_vertical += delta.y * 0.3;

            // Clamp vertical angle to avoid flipping
            if (angle_vertical > 89.0) angle_vertical = 89.0;
            if (angle_vertical < -89.0) angle_vertical = -89.0;

            // Zoom with mouse wheel
            const wheel = ray.getMouseWheelMove();
            distance -= wheel;
            if (distance < 0.1) distance = 0.1;

            // Calculate new camera position using spherical coordinates
            const rad_h = angle_horizontal * std.math.pi / 180.0;
            const rad_v = angle_vertical * std.math.pi / 180.0;

            camera.position.x = target.x + distance * @cos(rad_v) * @cos(rad_h);
            camera.position.y = target.y + distance * @sin(rad_v);
            camera.position.z = target.z + distance * @cos(rad_v) * @sin(rad_h);
        }

        ray.beginDrawing();
        defer ray.endDrawing();

        ray.clearBackground(ray.getColor(BACK_COLOR)); // Dark navy

        camera.begin();
        defer camera.end();

        std.debug.print("camera.position = {any}\n", .{camera.position});

        // Ground plane (XZ plane, horizontal)
        ray.drawPlane(
            .{ .x = 0, .y = -0.01, .z = 0 },
            .{ .x = 16, .y = 16 },
            ray.getColor(BOARD_COLOR),
        );

        // Reference grid on the plane
        ray.drawGrid(16, 1.0);

        // Cube resting on the plane (center at y=0.5, bottom touches y=0)
        ray.drawCube(
            .{ .x = 0, .y = 0.5, .z = 0 },
            1.0,
            1.0,
            1.0,
            ray.getColor(SNAKE_COLOR), // Coral red
        );

        // Wireframe outline for visual definition
        ray.drawCubeWires(
            .{ .x = 0, .y = 0.5, .z = 0 },
            1.0,
            1.0,
            1.0,
            ray.getColor(BOARD_COLOR),
        );
    }
}
