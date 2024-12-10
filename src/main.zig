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
    const alloc = gpa.allocator();

    var db = Sqlite3.init(db_filename, .{ .alloc = alloc }) catch |err| {
        std.debug.print("Failed to connect to SQLite", .{});
        return err;
    };
    defer db.deinit();

    migrate(db.sqlite3, .{ .emit_debug = true }) catch |err| {
        db.printError("migrate");
        return err;
    };

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

    const rules_count = try zvenc.data.selectSchedulerRulesCount(&db);
    std.debug.print("Rules count: {any}\n", .{rules_count});

    if (first_run.compare(today) == .gt) {
        std.debug.print("We've already ran today!\n", .{});
    } else {
        var rules_list = std.ArrayList(zvenc.rule.Rule).init(alloc);
        defer {
            for (rules_list.items) |item| {
                item.deinit(alloc);
            }
            rules_list.deinit();
        }
        const iter = try zvenc.data.selectSchedulerRules(&db);
        defer iter.deinit();
        std.debug.print("Iter: {any}\n", .{iter});
        while (try iter.next()) |row| {
            std.debug.print("Row: {any}\n", .{row});
            const rule = try zvenc.rule.Rule.parse(row.rule, alloc);
            errdefer rule.deinit(alloc);
            try rules_list.append(rule);
        }

        var run_date = first_run;
        while (run_date.compare(today) != .gt) : (run_date = run_date.nextDate()) {}
    }

    try zvenc.data.updateLastRunTimeMs(&db, now);
}

// Make sure all migrations work fine on a fresh database
test "migrate" {
    const db = try Sqlite3.init(":memory:", .{ .alloc = std.testing.failing_allocator });
    try migrate(db.sqlite3, .{ .emit_debug = true });
}

test {
    std.testing.refAllDecls(@This());
}
