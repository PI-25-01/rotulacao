const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");
const zc = @import("zclay");
const rz = @import("raylib_render_clay.zig");

const WINDOW_WIDTH = 1080;
const WINDOW_HEIGHT = 720;

var image_og : ?rl.Texture = null;
var image_copy : ?rl.Texture = null;

pub fn main() !void
{
	var gpa = std.heap.DebugAllocator(.{}).init;
	var allocator = gpa.allocator();

	rl.setConfigFlags(.{ .window_resizable = true});
	rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Equalização do histograma");
	defer {
		if (image_og) |tx|
		{
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

	while (!rl.windowShouldClose())
	{
		zc.setLayoutDimensions(.{ .w = @floatFromInt(rl.getScreenWidth()), .h = @floatFromInt(rl.getScreenHeight())});
		zc.setPointerState(.{ .x = rl.getMousePosition().x, .y = rl.getMousePosition().y}, rl.isMouseButtonDown(.left));
		zc.updateScrollContainers(true, .{ .x = rl.getMousePosition().x,
			.y = rl.getMousePosition().y}, rl.getFrameTime());

		if (rl.isFileDropped())
		{
			if (image_og) |tx	|
			{
				rl.unloadTexture(tx);
			}
			const paths = rl.loadDroppedFiles();
			image_og = try rl.loadTexture(std.mem.span(paths.paths[0]));
			//image_copy = try rl.loadTexture(std.mem.span(paths.paths[0]));

			const img_width : usize = @intCast(image_og.?.width);
			const img_height : usize = @intCast(image_og.?.height);
			var intermediate = try rl.loadImage(std.mem.span(paths.paths[0]));
			var colors = try rl.loadImageColors(intermediate);

			for (0..img_width) |i|
			{
				for (0..img_height) |j|
				{
					const is_white  = (@as(usize, @intCast(colors[j * img_width + i].r))
						+ @as(usize, @intCast(colors[j * img_width + i].g))
						+ @as(usize, @intCast(colors[j * img_width + i].b))
						+ @as(usize, @intCast(colors[j * img_width + i].a))) / 4 > 127;
					if (is_white)
					{
						colors[j * img_width + i] = .white;
					}
					else
					{
						colors[j * img_width + i] = .black;
					}
				}
			}
			for (0..img_width) |i|
			{
				for (0..img_height) |j|
				{
					if(colors[j * img_width + i].r == 0)
					{
						continue;
					}

					if (i == 0 and j == 0) {
						continue;
					}
					else if (i == 0)
					{
						const left  = colors[j * img_width + i - img_width];
						if (left.r != 0)
						{
							colors[j * img_width + i] = left;
						}
					}
					else if (j == 0)
					{
						const above  = colors[j * img_width + i - 1];
						if (above.r != 0)
						{
							colors[j * img_width + i] = above;
						}
					}
					else
					{
						const left  = colors[j * img_width + i - img_width];
						const above  = colors[j * img_width + i - 1];
						if(left.r != 0 and above.r != 0)
						{
							colors[j * img_width + i] = above;
						}
						else if(left.r != 0)
						{
							colors[j * img_width + i] = left;
						}
						else if(above.r != 0)
						{
							colors[j * img_width + i] = above;
						}
						else
						{
							colors[j * img_width + i] = .{ .r = std.crypto.random.int(u8), .g = std.crypto.random.int(u8), .b = std.crypto.random.int(u8), .a = std.crypto.random.int(u8)};
						}
					}
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
			if (image_og) |_|
			{
				zc.UI()(.{
					.id = .ID("Original"),
					.layout = .{
						.direction = .top_to_bottom,
						.sizing = .{ .w = .percent(0.5), .h = .grow },
						.padding = .all(16),
						.child_alignment = .{ .x = .center, .y = .top },
					},
					.scroll = .{ .horizontal = true, .vertical = true},
					.image = .{
						.image_data = &image_og,
						.source_dimensions = .{
							.w = @floatFromInt(image_og.?.width),
							.h = @floatFromInt(image_og.?.height)
						}
					},
				})({});
				zc.UI()(.{
					.id = .ID("Copy"),
					.layout = .{
						.direction = .top_to_bottom,
						.sizing = .{ .w = .percent(0.5), .h = .grow },
						.padding = .all(16),
						.child_alignment = .{ .x = .center, .y = .top },
					},
					.image = .{
						.image_data = &image_copy,
						.source_dimensions = .{
							.w = @floatFromInt(image_og.?.width),
							.h = @floatFromInt(image_og.?.height)
						}
					},
					.scroll = .{ .horizontal = true, .vertical = true},
				})({});
			}
			else
			{
				zc.UI()(.{
					.id = .ID("Original"),
					.layout = .{
						.direction = .top_to_bottom,
						.sizing = .{ .h = .percent(0.5), .w = .percent(0.5) },
						.padding = .all(16),
						.child_alignment = .{ .x = .center, .y = .top },
						.child_gap = 16,
					},
					.scroll = .{ .horizontal = true, .vertical = true},
					.background_color = rz.raylibColorToClayColor(.black),
				})({});
				zc.UI()(.{
					.id = .ID("Copy"),
					.layout = .{
						.direction = .top_to_bottom,
						.sizing = .{ .w = .percent(0.5), .h = .grow },
						.padding = .all(16),
						.child_alignment = .{ .x = .center, .y = .top },
					},
					.scroll = .{ .horizontal = true, .vertical = true},
					.background_color = rz.raylibColorToClayColor(.blue),
				})({});
			}
		});
    	var cmds = zc.endLayout();
		try rz.clayRaylibRender(&cmds, allocator);
	}
}