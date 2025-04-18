const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");
const zc = @import("zclay");
const rz = @import("raylib_render_clay.zig");

const WINDOW_WIDTH = 1080;
const WINDOW_HEIGHT = 720;

var image_og: ?rl.Texture = null;
var image_copy: ?rl.Texture = null;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    var allocator = gpa.allocator();

    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Rotulação");
    defer {
        if (image_og) |tx| {
            rl.unloadTexture(tx);
            rl.unloadTexture(image_copy.?);
        }
        rl.closeWindow();
    }

    const min_memory_size: u32 = zc.minMemorySize();
    const memory = try allocator.alloc(u8, min_memory_size);
    defer allocator.free(memory);
    const arena: zc.Arena = zc.createArenaWithCapacityAndMemory(memory);
    _ = zc.initialize(arena, .{ .w = WINDOW_WIDTH, .h = WINDOW_HEIGHT }, .{});
    zc.setMeasureTextFunction(void, {}, rz.measureText);

    while (!rl.windowShouldClose()) {
        zc.setLayoutDimensions(.{ .w = @floatFromInt(rl.getScreenWidth()), .h = @floatFromInt(rl.getScreenHeight()) });
        zc.setPointerState(
            .{ .x = rl.getMousePosition().x, .y = rl.getMousePosition().y },
            rl.isMouseButtonDown(.left),
        );
        zc.updateScrollContainers(
            true,
            .{ .x = rl.getMouseWheelMoveV().x, .y = rl.getMouseWheelMoveV().y },
            rl.getFrameTime(),
        );

        if (rl.isFileDropped()) {
            if (image_og) |tx| {
                rl.unloadTexture(tx);
            }
            const paths = rl.loadDroppedFiles();
            image_og = try rl.loadTexture(std.mem.span(paths.paths[0]));

            const img_width: usize = @intCast(image_og.?.width);
            const img_height: usize = @intCast(image_og.?.height);
            var intermediate = try rl.loadImage(std.mem.span(paths.paths[0]));
            var colors = try rl.loadImageColors(intermediate);

            for (colors) |*cor| {
                const is_white = (@as(usize, @intCast(cor.*.r)) +
                    @as(usize, @intCast(cor.*.g)) +
                    @as(usize, @intCast(cor.*.b)) +
                    @as(usize, @intCast(cor.*.a))) / 4 >= 127;
                if (is_white) {
                    cor.* = .white;
                } else {
                    cor.* = .black;
                }
            }

            for (colors, 0..) |*cor, i| {
                if (isSameColor(cor.*, .white)) {
                    var queue = std.PriorityQueue(
                        struct { usize, *rl.Color },
                        void,
                        cmpColors,
                    ).init(allocator, {});

                    // Marcando raiz
                    cor.r = std.crypto.random.int(u8);
                    cor.g = std.crypto.random.int(u8);
                    cor.b = std.crypto.random.int(u8);
                    cor.a = 255;
                    try queue.add(.{ i, cor });
                    while (queue.count() > 0) {
                        const atual = queue.remove();
                        const hood = neighbor4(
                            atual.@"0" % img_width,
                            atual.@"0" / img_width,
                            &colors,
                            img_width,
                            img_height,
                        );
                        for (hood) |value| {
                            if (value) |nei| {
                                if (!isSameColor(cor.*, nei.@"1".*)) {
                                    nei.@"1".r = cor.r;
                                    nei.@"1".g = cor.g;
                                    nei.@"1".b = cor.b;
                                    nei.@"1".a = cor.a;
                                    try queue.add(nei);
                                }
                            }
                        }
                    }
                    queue.clearAndFree();
                }
            }

            intermediate.data = colors.ptr;
            intermediate.format = .uncompressed_r8g8b8a8;

            image_copy = try rl.loadTextureFromImage(intermediate);

            rl.unloadImageColors(colors);
            rl.unloadDroppedFiles(paths);
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        zc.beginLayout();
        zc.UI()(.{
            .id = .ID("OuterContainer"),
            .layout = .{
                .direction = .left_to_right,
                .sizing = .grow,
                .padding = .all(16),
            },
            .background_color = rz.raylibColorToClayColor(.white),
        })({
            if (image_og) |_| {
                zc.UI()(.{
                    .id = .ID("Original"),
                    .layout = .{
                        .direction = .top_to_bottom,
                        .sizing = .{ .w = .percent(0.5), .h = .grow },
                        .padding = .all(16),
                        .child_alignment = .{ .x = .center, .y = .top },
                    },
                    .scroll = .{ .vertical = true },
                    .image = .{ .image_data = &image_og, .source_dimensions = .{
                        .w = @floatFromInt(image_og.?.width),
                        .h = @floatFromInt(image_og.?.height),
                    } },
                })({});
                zc.UI()(.{
                    .id = .ID("Copy"),
                    .layout = .{
                        .direction = .top_to_bottom,
                        .sizing = .{ .w = .percent(0.5), .h = .grow },
                        .padding = .all(16),
                        .child_alignment = .{ .x = .center, .y = .top },
                    },
                    .image = .{ .image_data = &image_copy, .source_dimensions = .{
                        .w = @floatFromInt(image_og.?.width),
                        .h = @floatFromInt(image_og.?.height),
                    } },
                    .scroll = .{ .vertical = true },
                })({});
            } else {
                zc.UI()(.{
                    .id = .ID("Original"),
                    .layout = .{
                        .direction = .top_to_bottom,
                        .sizing = .{ .h = .percent(1), .w = .percent(0.5) },
                        .padding = .all(16),
                        .child_alignment = .{ .x = .center, .y = .top },
                        .child_gap = 16,
                    },
                    .scroll = .{ .horizontal = true, .vertical = true },
                })({});
                zc.UI()(.{
                    .id = .ID("Copy"),
                    .layout = .{
                        .direction = .top_to_bottom,
                        .sizing = .{ .w = .percent(1), .h = .percent(0.5) },
                        .padding = .all(16),
                        .child_alignment = .{ .x = .center, .y = .top },
                    },
                    .scroll = .{ .horizontal = true, .vertical = true },
                })({});
            }
        });
        var cmds = zc.endLayout();
        try rz.clayRaylibRender(&cmds, allocator);
    }
}

fn isSameColor(color1: rl.Color, color2: rl.Color) bool {
    return color1.r == color2.r and color1.g == color2.g and color1.b == color2.b and color1.a == color2.a;
}

fn cmpColors(_: void, _: struct { usize, *rl.Color }, _: struct { usize, *rl.Color }) std.math.Order {
    return std.math.Order.eq;
}

fn neighbor4(x: usize, y: usize, cores: *[]rl.Color, width: usize, height: usize) [4]?struct { usize, *rl.Color } {
    const up: ?struct { usize, *rl.Color } = up: {
        if (y == 0) {
            break :up null;
        } else if (isSameColor(cores.*[(y - 1) * width + x], .white)) {
            break :up .{ (y - 1) * width + x, &cores.*[(y - 1) * width + x] };
        } else {
            break :up null;
        }
    };

    const down: ?struct { usize, *rl.Color } = down: {
        if (y == height - 1) {
            break :down null;
        } else if (isSameColor(cores.*[(y + 1) * width + x], .white)) {
            break :down .{ (y + 1) * width + x, &cores.*[(y + 1) * width + x] };
        } else {
            break :down null;
        }
    };

    const left: ?struct { usize, *rl.Color } = left: {
        if (x == 0) {
            break :left null;
        } else if (isSameColor(cores.*[y * width + x - 1], .white)) {
            break :left .{ y * width + x - 1, &cores.*[y * width + x - 1] };
        } else {
            break :left null;
        }
    };

    const right: ?struct { usize, *rl.Color } = right: {
        if (x == width - 1) {
            break :right null;
        } else if (isSameColor(cores.*[y * width + x + 1], .white)) {
            break :right .{ y * width + x + 1, &cores.*[y * width + x + 1] };
        } else {
            break :right null;
        }
    };
    return .{ up, down, left, right };
}
