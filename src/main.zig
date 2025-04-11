const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");
const zc = @import("zclay");
const rz = @import("raylib_render_clay.zig");

const WINDOW_WIDTH = 1080;
const WINDOW_HEIGHT = 720;

const LutData = struct {
	rk: usize,
	nk: usize,
	pr_rk: f64,
	freq: f64,
	eq: f64,
};

var color_levels = 10;

pub fn main() !void
{
	var gpa = std.heap.DebugAllocator(.{}).init;
	var allocator = gpa.allocator();

	rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Equalização do histograma");
	defer rl.closeWindow();

	const min_memory_size: u32 = zc.minMemorySize();
	const memory = try allocator.alloc(u8, min_memory_size);
	defer allocator.free(memory);
	const arena: zc.Arena = zc.createArenaWithCapacityAndMemory(memory);
	_ = zc.initialize(arena, .{ .h = 1000, .w = 1000 }, .{});
	zc.setMeasureTextFunction(void, {}, rz.measureText);

	while (!rl.windowShouldClose())
	{
		rl.beginDrawing();
		defer rl.endDrawing();

		rl.clearBackground(.ray_white);

		zc.beginLayout();
		zc.UI()(.{
			.id = .ID("OuterContainer"),
			.layout = .{ .direction = .left_to_right, .sizing = .grow, .padding = .all(16), .child_gap = 16 },
			.background_color = rz.raylibColorToClayColor(.white),
		})({
			zc.UI()(.{
				.id = .ID("SideBar"),
				.layout = .{
					.direction = .top_to_bottom,
					.sizing = .{ .h = .grow, .w = .fixed(300) },
					.padding = .all(16),
					.child_alignment = .{ .x = .center, .y = .top },
					.child_gap = 16,
				},
				.background_color = rz.raylibColorToClayColor(.gray),
			})({
				zc.UI()(.{
					.id = .ID("ProfilePictureOuter"),
					.layout = .{ .sizing = .{ .w = .grow }, .padding = .all(16),
					.child_alignment = .{ .x = .left, .y = .center },
					.child_gap = 16 },
					.background_color = rz.raylibColorToClayColor(.red),
				})({
					zc.UI()(.{
						.id = .ID("ProfilePicture"),
						.layout = .{ .sizing = .{ .h = .fixed(60), .w = .fixed(60) } },
					})({});
					zc.text("Clay - UI Library", .{ .font_size = 24, .color = rz.raylibColorToClayColor(.gray)});
				});
			});

			zc.UI()(.{
				.id = .ID("MainContent"),
				.layout = .{ .sizing = .grow },
				.background_color = rz.raylibColorToClayColor(.gray),
			})({
				//...
			});
		});
    	var cmds = zc.endLayout();
		try rz.clayRaylibRender(&cmds, allocator);
	}
}