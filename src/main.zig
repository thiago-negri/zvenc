const std = @import("std");
const Sqlite3 = @import("zsqlite").Sqlite3;
const migrate = @import("zsqlite-migrate").migrate;
const zvenc = @import("./zvenc.zig");

pub fn main() !void {
    const db = Sqlite3.init("zvenc.db") catch |err| {
        std.debug.print("Failed to connect to SQLite", .{});
        return err;
    };
    defer db.deinit();

    {
        errdefer db.printError("migrate");
        try migrate(db.sqlite3, .{ .emit_debug = true });
    }

    const now = zvenc.date.Date.fromTimestamp(std.time.timestamp());
    std.debug.print("Today is {any}\n", .{now});

    const iter = try zvenc.data.selectSchedulerRules(db);
    std.debug.print("Iter: {any}\n", .{iter});
    while (try iter.next()) |row| {
        std.debug.print("Row: {any}\n", .{row});
    }
}

// Make sure all migrations work fine on a fresh database
test "migrate" {
    const db = try Sqlite3.init(":memory:");
    try migrate(db.sqlite3, .{ .emit_debug = true });
}

test {
    std.testing.refAllDecls(@This());
}
