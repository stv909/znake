const std = @import("std");
const ray = @import("raylib");

var rand: std.Random = undefined;

const BOARD_COLOR = 0x2E2E2EFF; // Jet Black
const SNAKE_COLOR = 0x81D4FAFF; // Light Blue Pastel
const FOOD_COLOR = 0xFFCDD2FF; // Soft Coral

const screen_width: comptime_int = 800;
const screen_height: comptime_int = 450;

const cell_size: comptime_int = 10;

const _cols: comptime_int = screen_width / cell_size;
const _rows: comptime_int = screen_height / cell_size;

const Vector2 = struct {
    x: i16,
    y: i16,
};

const Snake = struct {
    size: u16 = 10,
    segments: [1024]Vector2 = [_]Vector2{.{ .x = 0, .y = 0 }} ** 1024,
    pos: Vector2,
    bounds: Vector2,

    pub fn init(pos: Vector2, bounds: Vector2) Snake {
        return .{
            .pos = pos,
            .bounds = bounds,
        };
    }

    pub fn move(self: *Snake, delta: Vector2) void {
        self.pos.x += delta.x;
        self.pos.y += delta.y;

        if (self.pos.x >= self.bounds.x) {
            self.pos.x = 0;
        } else if (self.pos.x < 0) {
            self.pos.x = self.bounds.x - 1;
        }

        if (self.pos.y >= self.bounds.y) {
            self.pos.y = 0;
        } else if (self.pos.y < 0) {
            self.pos.y = self.bounds.y - 1;
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
    size: Vector2 = .{ .x = 8, .y = 8 },
    color: u32,
};

const PlayerDirection = enum(u8) {
    LEFT,
    RIGHT,
    TOP,
    BOTTOM,
};

const GameBoard = struct {
    cols: u16 = 0,
    rows: u16 = 0,
    rect_buffer: [_cols * _rows]Rect,
    player: Snake,
    player_direction: PlayerDirection,
    food: Rect,

    pub fn init() GameBoard {
        return .{
            .cols = _cols,
            .rows = _rows,
            .player = Snake.init(.{ .x = 10, .y = 10 }, .{ .x = @as(i16, @intCast(_cols)), .y = @as(i16, @intCast(_rows)) }),
            .player_direction = .RIGHT,
            .rect_buffer = [_]Rect{
                .{
                    .pos = .{ .x = 0, .y = 0 },
                    .color = 0x000000FF,
                },
            } ** 3600,
            .food = .{
                .pos = .{
                    .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _cols - 1))),
                    .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, _rows - 1))),
                },
                .color = FOOD_COLOR,
            },
        };
    }

    pub fn deinit(self: *GameBoard) void {
        _ = self;
        //self.rect_buffer.deinit();
    }

    pub fn predraw(self: *GameBoard) !void {
        //std.debug.assert(self.rect_buffer.len == 0);
        for (0..self.rows) |i| for (0..self.cols) |j| {
            self.rect_buffer[(i * self.cols) + j] = .{
                .size = .{ .x = 8, .y = 8 },
                .pos = .{ .x = @as(i16, @intCast(j)), .y = @as(i16, @intCast(i)) },
                .color = BOARD_COLOR,
            };
        };
    }

    pub fn draw(self: *GameBoard) void {
        //Draw food
        const food_coord: u16 = (@as(u16, @intCast(self.food.pos.y)) * self.cols) + @as(u16, @intCast(self.food.pos.x));
        self.rect_buffer[food_coord].color = FOOD_COLOR;

        //Draw player
        for (self.player.segments[0..self.player.size], 0..) |seg, n| {
            const flat_coord: u16 = (@as(u16, @intCast(seg.y)) * self.cols) + @as(u16, @intCast(seg.x));
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
                @as(i32, @intCast(rect.pos.x * 10)),
                @as(i32, @intCast(rect.pos.y * 10)),
                @as(i32, @intCast(rect.size.x)),
                @as(i32, @intCast(rect.size.y)),
                ray.getColor(rect.color),
            );
            rect.color = BOARD_COLOR;
        }
    }
};

// Why I even need this function?
//export fn _start(init: std.process.Init) void {
//    run(init) catch |err| std.debug.print("Error: {}\n", .{err});
//}

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

    ray.setTargetFPS(10); // Set our game to run at 60 frames-per-second

    while (!ray.windowShouldClose()) {
        ray.beginDrawing();
        defer ray.endDrawing();

        gb.draw();

        switch (gb.player_direction) {
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
        .left => board.player_direction = .LEFT,
        .right => board.player_direction = .RIGHT,
        .up => board.player_direction = .TOP,
        .down => board.player_direction = .BOTTOM,
        .a => board.player_direction = .LEFT,
        .d => board.player_direction = .RIGHT,
        .w => board.player_direction = .TOP,
        .s => board.player_direction = .BOTTOM,
        else => {},
    }
}

fn pollPlayerEvents(board: *GameBoard) void {
    if (board.player.pos.x == board.food.pos.x and board.player.pos.y == board.food.pos.y) {
        board.player.size += 1;
        board.food.pos = .{
            .x = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, board.cols - 1))),
            .y = @as(i16, @intCast(rand.intRangeAtMost(u16, 0, board.rows - 1))),
        };
    }
}
