const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zvenc",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add SQLite
    const zsqlite = b.dependency("zsqlite", .{ .target = target, .optimize = optimize });
    const zsqlite_module = zsqlite.module("zsqlite");
    exe.root_module.addImport("zsqlite", zsqlite_module);

    // Add SQLite Migrate
    const zsqlite_migrate = b.dependency("zsqlite-migrate", .{
        .target = target,
        .optimize = optimize,
        .migration_root_path = @as([]const u8, "./migrations/"),
        .minify_sql = true,
    });
    const zsqlite_migrate_module = zsqlite_migrate.module("zsqlite-migrate");
    exe.root_module.addImport("zsqlite-migrate", zsqlite_migrate_module);

    // Add SQL Minify
    // All files within ./src/sqls will be embedded in the executable
    // zig fmt: off
    const zsqlite_minify = b.dependency("zsqlite-minify", .{
        .target = target,
        .optimize = optimize,
        .minify_root_path = @as([]const u8, "./src/sqls/"),
        .minify_files_prefix = @as([]const u8, "sqls")
    });
    // zig fmt: on
    const zsqlite_minify_module = zsqlite_minify.module("zsqlite-minify");
    exe.root_module.addImport("zsqlite-minify", zsqlite_minify_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("zsqlite", zsqlite_module);
    exe_unit_tests.root_module.addImport("zsqlite-migrate", zsqlite_migrate_module);
    exe_unit_tests.root_module.addImport("zsqlite-minify", zsqlite_minify_module);
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
