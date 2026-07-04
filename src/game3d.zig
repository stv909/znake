const std = @import("std");
const ray = @import("raylib");

var rand: std.Random = undefined;

const BACK_COLOR = 0x404040FF;
const WALL_COLOR = 0x2E502EFF; // Greenish
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

/// Procedurally renders a raspberry from 3D primitives.
/// The raspberry consists of a dark core sphere, ~39 drupelet spheres
/// arranged in interlocking helical rings, a stem cylinder, and a calyx
/// of small green cylinders.
fn drawRaspberry(pos: ray.Vector3, scale: f32) void {
    const pi = std.math.pi;

    // ── Core parameters ──────────────────────────────────────────
    const core_radius = 0.32 * scale;
    const shell_radius = 0.55 * scale; // virtual sphere for drupelet centers
    const drupelet_radius = 0.175 * scale;

    // ── Color palette ────────────────────────────────────────────
    const core_col = ray.Color.init(90, 15, 20, 255); // dark maroon
    const d1 = ray.Color.init(185, 25, 40, 255); // deep raspberry
    const d2 = ray.Color.init(210, 40, 55, 255); // mid raspberry
    const d3 = ray.Color.init(235, 60, 75, 255); // bright raspberry
    const d4 = ray.Color.init(250, 100, 115, 255); // highlight
    const green = ray.Color.init(40, 120, 40, 255);
    const green_light = ray.Color.init(60, 150, 50, 255);

    // ── Core ─────────────────────────────────────────────────────
    ray.drawSphereEx(
        .{ .x = pos.x, .y = pos.y + core_radius, .z = pos.z },
        core_radius,
        16,
        16,
        core_col,
    );

    // ── Drupelet layers ──────────────────────────────────────────
    // Each layer { phi_degrees, count, theta_phase_offset }
    const layers = [_]struct { phi: f32, count: u32, offset: f32 }{
        .{ .phi = 82, .count = 9, .offset = 0.0 },
        .{ .phi = 65, .count = 8, .offset = 0.35 },
        .{ .phi = 49, .count = 8, .offset = 0.0 },
        .{ .phi = 34, .count = 7, .offset = 0.28 },
        .{ .phi = 20, .count = 5, .offset = 0.0 },
        .{ .phi = 8, .count = 3, .offset = 0.2 },
    };

    const core_center_y = pos.y + core_radius;

    for (layers) |layer| {
        const phi = layer.phi * pi / 180.0;
        const n: f32 = @floatFromInt(layer.count);
        for (0..layer.count) |i| {
            const fi: f32 = @floatFromInt(i);
            const theta = (fi / n) * 2.0 * pi + layer.offset;

            const sx = shell_radius * @sin(phi);
            const dx = sx * @cos(theta);
            const dy = shell_radius * @cos(phi);
            const dz = sx * @sin(theta);

            // Pick varied color per drupelet
            const color_idx = (i + layer.count) % 4;
            const color = switch (color_idx) {
                0 => d1,
                1 => d2,
                2 => d3,
                else => d4,
            };

            ray.drawSphereEx(
                .{
                    .x = pos.x + dx,
                    .y = core_center_y + dy,
                    .z = pos.z + dz,
                },
                drupelet_radius,
                8,
                8,
                color,
            );
        }
    }

    // ── Apex drupelet ────────────────────────────────────────────
    const apex_y = core_center_y + shell_radius;
    ray.drawSphereEx(
        .{ .x = pos.x, .y = apex_y, .z = pos.z },
        drupelet_radius * 1.05,
        8,
        8,
        d3,
    );

    // ── Stem ─────────────────────────────────────────────────────
    const stem_base_y = apex_y + drupelet_radius * 1.05;
    const stem_height = 0.25 * scale;
    const stem_radius = 0.04 * scale;
    ray.drawCylinder(
        .{ .x = pos.x, .y = stem_base_y, .z = pos.z },
        stem_radius,
        stem_radius * 1.3,
        stem_height,
        8,
        green,
    );

    // ── Calyx (5 small green cylinders radiating from stem base) ─
    const calyx_base_y = stem_base_y;
    const calyx_len = 0.14 * scale;
    const calyx_radius = 0.025 * scale;
    const calyx_angle = 55.0 * pi / 180.0; // angle from vertical
    for (0..5) |i| {
        const fi: f32 = @floatFromInt(i);
        const theta = (fi / 5.0) * 2.0 * pi;
        const hx = calyx_len * @sin(calyx_angle) * @cos(theta);
        const hy = calyx_len * @cos(calyx_angle);
        const hz = calyx_len * @sin(calyx_angle) * @sin(theta);

        ray.drawCylinderEx(
            .{ .x = pos.x, .y = calyx_base_y, .z = pos.z },
            .{ .x = pos.x + hx, .y = calyx_base_y + hy, .z = pos.z + hz },
            calyx_radius,
            calyx_radius * 0.4,
            6,
            if (i % 2 == 0) green else green_light,
        );
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

        // Fruit
        drawRaspberry(.{ .x = 2.5 * _cell_size, .y = 0, .z = 0 }, 0.7);

        // Walls
        ray.drawCube(
            .{ .x = -0.5 * (_cols + 1) * _cell_size, .y = 0, .z = 0 },
            _cell_size,
            _cell_size,
            (_rows + 1) * _cell_size,
            ray.getColor(WALL_COLOR),
        );
        ray.drawCube(
            .{ .x = 0.5 * (_cols + 1) * _cell_size, .y = 0, .z = 0 },
            _cell_size,
            _cell_size,
            (_rows + 1) * _cell_size,
            ray.getColor(WALL_COLOR),
        );
        ray.drawCube(
            .{ .x = 0, .y = 0, .z = -0.5 * (_rows + 1) * _cell_size },
            (_cols + 1) * _cell_size,
            _cell_size,
            _cell_size,
            ray.getColor(WALL_COLOR),
        );
        ray.drawCube(
            .{ .x = 0, .y = 0, .z = 0.5 * (_rows + 1) * _cell_size },
            (_cols + 1) * _cell_size,
            _cell_size,
            _cell_size,
            ray.getColor(WALL_COLOR),
        );
    }
}
