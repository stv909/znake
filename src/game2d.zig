const std = @import("std");
const ray = @import("raylib");

var rand: std.Random = undefined;

const BOARD_COLOR = 0x2E2E2EFF; // Jet Black
const SNAKE_COLOR = 0x81D4FAFF; // Light Blue Pastel
const FOOD_COLOR = 0xFFCDD2FF; // Soft Coral

const raspberry_image_data = @embedFile("icons8-raspberry-24.png");

const screen_width: comptime_int = 900;
const screen_height: comptime_int = 800;
const _cols: comptime_int = 32;
const _rows: comptime_int = 32;
const _cell_size: comptime_int = 24;
const _margin_size = 2;
comptime {
    if (_cols * _rows >= 8192) {
        @compileError("board size exceeds maximum segment count");
    }
    if (_cell_size <= _margin_size) {
        @compileError("cell_size must be greater than margin_size");
    }
}
const _texture_offset = 1;

const Vector2 = struct {
    x: i16,
    y: i16,
};

const Snake = struct {
    size: u16 = _cell_size,
    segments: [1024]Vector2 = [_]Vector2{.{ .x = 0, .y = 0 }} ** 1024,
    pos: Vector2,
    bounds: Vector2,
    direction: PlayerDirection,

    pub fn init(pos: Vector2, bounds: Vector2, direction: PlayerDirection) Snake {
        return .{
            .pos = pos,
            .bounds = bounds,
            .direction = direction,
        };
    }

    fn reverse_direction(self: *Snake) void {
        switch (self.direction) {
            .RIGHT => self.direction = .LEFT,
            .LEFT => self.direction = .RIGHT,
            .TOP => self.direction = .BOTTOM,
            .BOTTOM => self.direction = .TOP,
        }
    }

    pub fn move(self: *Snake, delta: Vector2) void {
        self.pos.x += delta.x;
        self.pos.y += delta.y;

        if (self.pos.x >= self.bounds.x or self.pos.x < 0 or self.pos.y >= self.bounds.y or self.pos.y < 0) {
            self.reverse_direction();
            self.pos.x -= delta.x;
            self.pos.y -= delta.y;
        }
        //std.debug.print("x: {}, y:{}\n", .{ self.pos.x, self.pos.y });
        self.shift();
    }

    fn shift(self: *Snake) void {
        var i = self.size - 1;
        while (i > 0) : (i -= 1) {
            self.segments[i] = self.segments[i - 1];
        }
        self.segments[0] = self.pos;
    }
};

const Rect = struct {
    pos: Vector2,
    size: Vector2 = .{ .x = _cell_size - _margin_size, .y = _cell_size - _margin_size },
    color: u32,
};

const PlayerDirection = enum(u8) {
    LEFT,
    RIGHT,
    TOP,
    BOTTOM,
};

const GameBoard = struct {
    rect_buffer: [_cols * _rows]Rect,
    player: Snake,
    food: Rect,
    food_texture: ray.Texture = undefined,

    pub fn init() GameBoard {
        std.debug.print("\ngame board size {d}\n", .{(_cols * _rows)});
        return .{
            .player = Snake.init(.{ .x = 10, .y = 10 }, .{ .x = @as(i16, @intCast(_cols)), .y = @as(i16, @intCast(_rows)) }, .RIGHT),
            .rect_buffer = [_]Rect{
                .{
                    .pos = .{ .x = 0, .y = 0 },
                    .color = 0x000000FF,
                },
            } ** (_cols * _rows),
            .food = .{
                .pos = .{
                    .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _cols - 1))),
                    .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _rows - 1))),
                },
                .color = FOOD_COLOR,
            },
            .food_texture = undefined,
        };
    }

    pub fn deinit(self: *GameBoard) void {
        ray.unloadTexture(self.food_texture);
    }

    pub fn predraw(self: *GameBoard) !void {
        //std.debug.assert(self.rect_buffer.len == 0);
        for (0.._rows) |i| for (0.._cols) |j| {
            self.rect_buffer[(i * _cols) + j] = .{
                .size = .{ .x = _cell_size - _margin_size, .y = _cell_size - _margin_size },
                .pos = .{ .x = @as(i16, @intCast(j)), .y = @as(i16, @intCast(i)) },
                .color = BOARD_COLOR,
            };
        };
    }

    pub fn loadTextures(self: *GameBoard) !void {
        const image = try ray.loadImageFromMemory(".png", raspberry_image_data);
        defer ray.unloadImage(image);
        self.food_texture = try ray.loadTextureFromImage(image);
    }

    pub fn draw(self: *GameBoard) void {
        //Draw player
        for (self.player.segments[0..self.player.size], 0..) |seg, n| {
            const flat_coord: u16 = (@as(u16, @intCast(seg.y)) * _cols) + @as(u16, @intCast(seg.x));
            std.debug.assert(flat_coord < self.rect_buffer.len);
            self.rect_buffer[flat_coord].color = SNAKE_COLOR;

            if (n > 0 and self.player.segments[0].x == seg.x and self.player.segments[0].y == seg.y) {
                self.player.size = 3;
            }
            //std.debug.print("Segment: {}, pos: {any}\n", .{ n, seg });
        }

        //Draw board
        for (&self.rect_buffer) |*rect| {
            ray.drawRectangle(
                @as(i32, @intCast(rect.pos.x * _cell_size)),
                @as(i32, @intCast(rect.pos.y * _cell_size)),
                @as(i32, @intCast(rect.size.x)),
                @as(i32, @intCast(rect.size.y)),
                ray.getColor(rect.color),
            );
            rect.color = BOARD_COLOR;
        }

        //Draw food texture on top of the board
        ray.drawTexture(
            self.food_texture,
            @as(i32, @intCast(self.food.pos.x)) * _cell_size - _texture_offset,
            @as(i32, @intCast(self.food.pos.y)) * _cell_size - _texture_offset,
            ray.getColor(0xFFFFFFFF),
        );
    }
};

pub fn run(init: std.process.Init) !void {
    // Initialize your deterministic PRNG with the seed
    const timestamp = std.Io.Clock.now(.real, init.io);
    const seconds = std.Io.Timestamp.toSeconds(timestamp);
    const seed: u64 = @as(u64, @intCast(seconds));
    var prng = std.Random.DefaultPrng.init(seed);
    rand = prng.random();

    var gb = GameBoard.init();
    defer gb.deinit();

    try gb.predraw();

    ray.initWindow(screen_width, screen_height, "znake");
    errdefer ray.closeWindow();
    defer ray.closeWindow(); // Close window and OpenGL context

    try gb.loadTextures();

    ray.setTargetFPS(10); // Set our game to run at 60 frames-per-second

    while (!ray.windowShouldClose()) {
        ray.beginDrawing();
        defer ray.endDrawing();

        gb.draw();

        switch (gb.player.direction) {
            .RIGHT => gb.player.move(.{ .x = 1, .y = 0 }),
            .LEFT => gb.player.move(.{ .x = -1, .y = 0 }),
            .TOP => gb.player.move(.{ .x = 0, .y = -1 }),
            .BOTTOM => gb.player.move(.{ .x = 0, .y = 1 }),
        }

        ray.clearBackground(ray.getColor(0x000000FF));

        pollKeyEvents(&gb);
        pollPlayerEvents(&gb);
    }
}

fn pollKeyEvents(board: *GameBoard) void {
    const ky = ray.getKeyPressed();
    switch (ky) {
        .a, .left => board.player.direction = .LEFT,
        .d, .right => board.player.direction = .RIGHT,
        .w, .up => board.player.direction = .TOP,
        .s, .down => board.player.direction = .BOTTOM,
        else => {},
    }
}

fn pollPlayerEvents(board: *GameBoard) void {
    if (board.player.pos.x == board.food.pos.x and board.player.pos.y == board.food.pos.y) {
        board.player.size += 1;
        board.food.pos = .{
            .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _cols - 1))),
            .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _rows - 1))),
        };
    }
}
