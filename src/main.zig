const std = @import("std");
const Sqlite3 = @import("zsqlite").Sqlite3;
const migrate = @import("zsqlite-migrate").migrate;
const scheduler = @import("scheduler.zig");

const print = std.debug.print;

pub fn main() !void {
    const db = Sqlite3.init("zvenc.db") catch |err| {
        print("Failed to connect to SQLite", .{});
        return err;
    };
    defer db.deinit();

    try migrate(db.sqlite3);
}
