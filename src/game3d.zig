const std = @import("std");
const ray = @import("raylib");

var rand: std.Random = undefined;

const BACK_COLOR = 0x404040FF;
const BOARD_COLOR = 0x2E2E2EFF; // Jet Black
const SNAKE_COLOR = 0x81D4FAFF; // Light Blue Pastel
//const FOOD_COLOR = 0xFFCDD2FF; // Soft Coral

const screen_width: comptime_int = 900;
const screen_height: comptime_int = 800;
const _cols: comptime_int = 20;
const _rows: comptime_int = 12;
const _cell_size: comptime_int = 1.0;
comptime {
    if (_cols * _rows >= 8192) {
        @compileError("board size exceeds maximum segment count");
    }
}

pub fn run(init: std.process.Init) !void {
    // Initialize your deterministic PRNG with the seed
    const timestamp = std.Io.Clock.now(.real, init.io);
    const seconds = std.Io.Timestamp.toSeconds(timestamp);
    const seed: u64 = @as(u64, @intCast(seconds));
    var prng = std.Random.DefaultPrng.init(seed);
    rand = prng.random();
    std.debug.print("rand {d}\n", .{rand.intRangeAtMost(u16, 0, 100)});

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
            if (distance < 0.1 * _cell_size) distance = 0.1 * _cell_size;

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

        // Ground plane (XZ plane, horizontal)
        ray.drawPlane(
            .{ .x = 0, .y = -0.03 * _cell_size, .z = 0 },
            .{ .x = _cols * _cell_size, .y = _rows * _cell_size },
            ray.getColor(BOARD_COLOR),
        );

        // Reference grid on the plane
        ray.drawGrid(@max(_cols, _rows), _cell_size);

        // Cube resting on the plane (center at y=0.5, bottom touches y=0)
        ray.drawCube(
            .{ .x = 0, .y = 0.5 * _cell_size, .z = 0 },
            _cell_size,
            _cell_size,
            _cell_size,
            ray.getColor(SNAKE_COLOR),
        );

        // Wireframe outline for visual definition
        ray.drawCubeWires(
            .{ .x = 0, .y = 0.5 * _cell_size, .z = 0 },
            _cell_size,
            _cell_size,
            _cell_size,
            ray.getColor(SNAKE_COLOR),
        );
    }
}
