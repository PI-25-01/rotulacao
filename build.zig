const std = @import("std");

pub fn build(b: *std.Build) void
{
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const exe_mod = b.createModule(.{
		.root_source_file = b.path("src/main.zig"),
		.target = target,
		.optimize = optimize,
	});

	const exe = b.addExecutable(.{
		.name = "rotulacao",
		.root_module = exe_mod,
	});
	b.installArtifact(exe);

	const raydep = b.dependency("raylib_zig", .{
		.target = target,
		.optimize = optimize,
	});
	exe.linkLibrary(raydep.artifact("raylib"));
	exe.root_module.addImport("raylib", raydep.module("raylib"));
	exe.root_module.addImport("raygui", raydep.module("raygui"));

	const zclay_dep = b.dependency("zclay", .{
		.target = target,
		.optimize = optimize,
	});
	exe.root_module.addImport("zclay", zclay_dep.module("zclay"));

	const run_cmd = b.addRunArtifact(exe);

	run_cmd.step.dependOn(b.getInstallStep());

	if (b.args) |args| {
		run_cmd.addArgs(args);
	}

	const run_step = b.step("run", "Run the app");
	run_step.dependOn(&run_cmd.step);
}
