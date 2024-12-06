const migrate = @import("zsqlite-migrate").migrate;
const Sqlite3 = @import("zsqlite").Sqlite3;
const std = @import("std");
const zvenc = @import("./zvenc.zig");

const Gpa = std.heap.GeneralPurposeAllocator(.{});

const db_filename = "zvenc.db";
const my_timezone = .brazil;

pub fn main() !void {
    var gpa = Gpa{};
    defer _ = gpa.deinit();

    var db = Sqlite3.init(db_filename, .{ .alloc = gpa.allocator() }) catch |err| {
        std.debug.print("Failed to connect to SQLite", .{});
        return err;
    };
    defer db.deinit();

    {
        errdefer db.printError("migrate");
        try migrate(db.sqlite3, .{ .emit_debug = true });
    }

    const now = std.time.timestamp();
    const today = zvenc.Date.fromTimestamp(now, my_timezone);
    std.debug.print("Today is {any}\n", .{today});

    const last_run = try zvenc.data.selectLastRunTimeMs(&db);
    std.debug.print("Last run: {any}\n", .{last_run});

    const first_run = if (last_run) |date|
        zvenc.Date.fromTimestamp(date, .utc).nextDate()
    else
        zvenc.Date.fromTimestamp(now, my_timezone);

    std.debug.print("First run: {any}\n", .{first_run});

    if (first_run.compare(today) == .gt) {
        std.debug.print("We've already ran today!\n", .{});
    }

    const iter = try zvenc.data.selectSchedulerRules(&db);
    defer iter.deinit();
    std.debug.print("Iter: {any}\n", .{iter});
    while (try iter.next()) |row| {
        std.debug.print("Row: {any}\n", .{row});
    }

    try zvenc.data.updateLastRunTimeMs(&db, now);
}

// Make sure all migrations work fine on a fresh database
test "migrate" {
    const db = try Sqlite3.init(":memory:");
    try migrate(db.sqlite3, .{ .emit_debug = true });
}

test {
    std.testing.refAllDecls(@This());
}
