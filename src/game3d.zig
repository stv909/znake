const std = @import("std");
const ray = @import("raylib");

var rand: std.Random = undefined;

const BACK_COLOR = 0x404040FF;
const WALL_COLOR = 0x81D4FAFF; // Light Blue Pastel
const BOARD_COLOR = 0x2E2E2EFF; // Jet Black
//const FOOD_COLOR = 0xFFCDD2FF; // Soft Coral

const screen_width: comptime_int = 900;
const screen_height: comptime_int = 800;
const _cols: comptime_int = 20;
const _rows: comptime_int = 12;
const _cell_size: comptime_int = 1.0;
const _max_body_length: comptime_int = 128 * 1024;
comptime {
    if (_cols * _rows >= 8192) {
        @compileError("board size exceeds maximum segment count");
    }
}

/// Draw a snake head that fits inside one _cell_size cube.
///
///   pos   – world position (bottom-center of the cell)
///   dir   – normalised direction the snake faces
///   scale – size multiplier (1.0 fills one cell)
fn drawSnakeHead3rd(pos: ray.Vector3, dir: ray.Vector3, scale: f32) void {
    const s = scale;

    // Local coordinate frame
    const forward = dir.normalize();
    const world_up = ray.Vector3{ .x = 0, .y = 1, .z = 0 };
    const right = world_up.crossProduct(forward).normalize();
    const up = forward.crossProduct(right).normalize();

    // Local → world helper
    const L = struct {
        fn at(b: ray.Vector3, fx: f32, uy: f32, rz: f32, f: ray.Vector3, u: ray.Vector3, r: ray.Vector3) ray.Vector3 {
            return b.add(f.scale(fx)).add(u.scale(uy)).add(r.scale(rz));
        }
    }.at;

    // ── Palette ──────────────────────────────────────────────────
    const skin = ray.Color.init(100, 200, 100, 255);
    const eye_w = ray.Color.init(255, 255, 255, 255);
    const pupil = ray.Color.init(10, 10, 10, 255);
    const tongue = ray.Color.init(210, 35, 35, 255);

    // ── Head sphere ──────────────────────────────────────────────
    const head_r = 0.30 * s;
    const head_y = head_r; // bottom of sphere touches the cell floor
    ray.drawSphereEx(L(pos, 0, head_y, 0, forward, up, right), head_r, 18, 18, skin);

    // ── Eyes ─────────────────────────────────────────────────────
    const eye_r = 0.065 * s;
    const pupil_r = 0.032 * s;
    const eye_fwd = 0.20 * s; // 0.04
    const eye_uy = head_y + head_r * 0.45; // 0.55
    const eye_lz = 0.09 * s;
    const pupil_fwd = 0.038 * s; // 0.018

    // Left
    ray.drawSphereEx(L(pos, eye_fwd, eye_uy, eye_lz, forward, up, right), eye_r, 16, 16, eye_w);
    ray.drawSphereEx(L(pos, eye_fwd + pupil_fwd, eye_uy + 0.01 * s, eye_lz, forward, up, right), pupil_r, 16, 16, pupil);
    // Right
    ray.drawSphereEx(L(pos, eye_fwd, eye_uy, -eye_lz, forward, up, right), eye_r, 16, 16, eye_w);
    ray.drawSphereEx(L(pos, eye_fwd + pupil_fwd, eye_uy + 0.01 * s, -eye_lz, forward, up, right), pupil_r, 16, 16, pupil);

    // ── Tongue shaft ─────────────────────────────────────────────
    const tongue_start = L(pos, head_r * 0.85, head_y * 0.85, 0, forward, up, right);
    const tongue_mid = L(pos, head_r * 0.85 + 0.14 * s, head_y * 0.85, 0, forward, up, right);
    ray.drawCylinderEx(tongue_start, tongue_mid, 0.012 * s, 0.009 * s, 6, tongue);

    // ── Forked tips ──────────────────────────────────────────────
    const fork_len = 0.06 * s;
    const fork_spread = 0.022 * s;
    inline for (.{ fork_spread, -fork_spread }) |spread| {
        ray.drawCylinderEx(
            tongue_mid,
            L(tongue_mid, fork_len, 0.008 * s, spread, forward, up, right),
            0.007 * s,
            0.003 * s,
            5,
            tongue,
        );
    }
}

fn drawSnakeHead1st(pos: ray.Vector3, dir: ray.Vector3, scale: f32) void {
    const s = scale;

    // Local coordinate frame
    const forward = dir.normalize();
    const world_up = ray.Vector3{ .x = 0, .y = 1, .z = 0 };
    const right = world_up.crossProduct(forward).normalize();
    const up = forward.crossProduct(right).normalize();

    // Local → world helper
    const L = struct {
        fn at(b: ray.Vector3, fx: f32, uy: f32, rz: f32, f: ray.Vector3, u: ray.Vector3, r: ray.Vector3) ray.Vector3 {
            return b.add(f.scale(fx)).add(u.scale(uy)).add(r.scale(rz));
        }
    }.at;

    // ── Palette ──────────────────────────────────────────────────
    const tongue = ray.Color.init(210, 35, 35, 255);

    // ── Head sphere ──────────────────────────────────────────────
    const head_r = 0.30 * s;
    const head_y = head_r; // bottom of sphere touches the cell floor

    // ── Tongue shaft ─────────────────────────────────────────────
    const tongue_start = L(pos, head_r * 0.85, head_y * 0.85, 0, forward, up, right);
    const tongue_mid = L(pos, head_r * 0.85 + 0.14 * s, head_y * 0.85, 0, forward, up, right);
    ray.drawCylinderEx(tongue_start, tongue_mid, 0.012 * s, 0.009 * s, 6, tongue);

    // ── Forked tips ──────────────────────────────────────────────
    const fork_len = 0.06 * s;
    const fork_spread = 0.022 * s;
    inline for (.{ fork_spread, -fork_spread }) |spread| {
        ray.drawCylinderEx(
            tongue_mid,
            L(tongue_mid, fork_len, 0.008 * s, spread, forward, up, right),
            0.007 * s,
            0.003 * s,
            5,
            tongue,
        );
    }
}

fn drawSnakeBodySegment(pos: ray.Vector3, scale: f32) void {
    const skin = ray.Color.init(100, 200, 100, 255);
    const r = 0.5 * scale;
    ray.drawSphereEx(.{ .x = pos.x, .y = pos.y + r, .z = pos.z }, r, 18, 18, skin);
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

var fps_camera = false;

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

    var player_direction: ray.Vector3 = .{ .x = 1.0, .y = 0.0, .z = 0.0 };
    var player_position = ray.Vector3.zero();
    var fruit_position: ray.Vector3 = .{ .x = rand.intRangeAtMost(i16, -_cols / 2, _cols / 2 - 1) * _cell_size, .y = 0.0, .z = rand.intRangeAtMost(i16, -_rows / 2, _rows / 2 - 1) * _cell_size };
    var player_body_length: u16 = 0;
    var player_body_positions: [_max_body_length]ray.Vector3 = [_]ray.Vector3{.{ .x = 0, .y = 0, .z = 0 }} ** _max_body_length;

    while (!ray.windowShouldClose()) {
        // Mouse orbital control: move to orbit, scroll to zoom
        if (fps_camera) {
            camera.position = player_position;
            camera.position = camera.position.add(.{ .x = 0.5, .y = 0.7, .z = 0.5 }).add(player_direction.scale(0));
            camera.target = player_position.add(player_direction.scale(10.0));
        } else {
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

        // Fruit
        drawRaspberry(.{ .x = fruit_position.x + 0.5 * _cell_size, .y = 0, .z = fruit_position.z + 0.5 * _cell_size }, 0.7);

        // Snake head
        if (fps_camera) {
            const p = player_position;
            drawSnakeHead1st(.{ .x = (p.x + 0.5 - 0.02) * _cell_size, .y = 0 * _cell_size, .z = p.z + 0.5 * _cell_size }, player_direction, 1.65);
        } else {
            const p = player_position;
            drawSnakeHead3rd(.{ .x = (p.x + 0.5 - 0.02) * _cell_size, .y = 0 * _cell_size, .z = p.z + 0.5 * _cell_size }, player_direction, 1.65);
        }

        // Snake body
        if (player_body_length > 0) {
            player_body_positions[0] = player_position.add(player_body_positions[0].add(player_position.scale(-1)).normalize());
            for (1..player_body_length) |i| {
                player_body_positions[i] = player_body_positions[i - 1].add(player_body_positions[i].add(player_body_positions[i - 1].scale(-1)).normalize());
            }
            for (0..player_body_length) |i| {
                const p = player_body_positions[i];
                drawSnakeBodySegment(.{ .x = (p.x + 0.5) * _cell_size, .y = 0, .z = (p.z + 0.5) * _cell_size }, 1.0);
            }
        }

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

        // Update game logic
        const delta = 0.03 * _cell_size;
        player_position = player_position.add(player_direction.scale(delta));

        if (player_position.distance(fruit_position) < 0.8 * _cell_size) {
            fruit_position = .{ .x = rand.intRangeAtMost(i16, -_cols / 2, _cols / 2 - 1) * _cell_size, .y = 0.0, .z = rand.intRangeAtMost(i16, -_rows / 2, _rows / 2 - 1) * _cell_size };
            player_body_positions[player_body_length] = switch (player_body_length) {
                0 => player_position.add(player_direction.scale(-1)),
                1 => player_body_positions[0].add(player_body_positions[0].add(player_position.scale(-1)).normalize()),
                else => player_body_positions[player_body_length - 1].add(player_body_positions[player_body_length - 1].add(player_body_positions[player_body_length - 2].scale(-1)).normalize()),
            };
            player_body_length += 1;
            std.debug.print("Fruit eaten!\n", .{}); // TODO: replace it by special animation to celebrate the moment
        }

        pollKeyEvents(&player_direction, &camera);
    }
}

fn pollKeyEvents(player_direction: *ray.Vector3, camera: *ray.Camera3D) void {
    const rotation_speed = 0.05;
    if (ray.isKeyDown(.a) or ray.isKeyDown(.left)) {
        player_direction.* = player_direction.*.rotateByAxisAngle(.{ .x = 0, .y = 1, .z = 0 }, rotation_speed);
    } else if (ray.isKeyDown(.d) or ray.isKeyDown(.right)) {
        player_direction.* = player_direction.*.rotateByAxisAngle(.{ .x = 0, .y = 1, .z = 0 }, -rotation_speed);
    }
    const ky = ray.getKeyPressed();
    switch (ky) {
        .space => {
            if (fps_camera) {
                camera.*.position = .{ .x = 6.0, .y = 5.0, .z = 6.0 };
                camera.*.target = .{ .x = 0.0, .y = 0.5, .z = 0.0 };
                fps_camera = false;
            } else {
                fps_camera = true;
            }
        },
        else => {},
    }
}
