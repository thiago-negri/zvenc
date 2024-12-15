const migrate = @import("zsqlite-migrate").migrate;
const Sqlite3 = @import("zsqlite").Sqlite3;
const std = @import("std");
const zvenc = @import("zvenc.zig");

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

    const check_date_start = if (last_run) |date|
        zvenc.Date.fromTimestamp(date, .utc).nextDate()
    else
        zvenc.Date.fromTimestamp(now, my_timezone);

    const check_date_end = today.addDays(60);

    std.debug.print("Today check start: {any}\n", .{check_date_start});

    const rules_count = try zvenc.data.selectSchedulerRulesCount(&db);
    std.debug.print("Rules count: {any}\n", .{rules_count});

    var scheduler_list = try std.ArrayList(zvenc.Scheduler).initCapacity(alloc, rules_count);
    defer {
        for (scheduler_list.items) |item| {
            item.deinit(alloc);
        }
        scheduler_list.deinit();
    }

    // Populate scheduler_list
    {
        const iter = try zvenc.data.selectSchedulerRules(&db);
        defer iter.deinit();
        while (try iter.next(alloc)) |row| {
            errdefer row.deinit(alloc);
            try scheduler_list.append(row);
        }
    }

    // Loop through all dates
    if (check_date_start.compare(check_date_end) == .gt) {
        std.debug.print("We've already ran today!\n", .{});
    } else {
        var check_date = check_date_start;
        while (check_date.compare(check_date_end) != .gt) : (check_date = check_date.nextDate()) {
            const timestamp = check_date.toTimestamp();
            for (scheduler_list.items) |scheduler| {
                const match = scheduler.rule_parsed.matches(check_date);
                if (match) {
                    // Generate an entry
                    const agenda = zvenc.AgendaInsert{
                        .scheduler_id = scheduler.id,
                        .description = scheduler.description,
                        .tags_csv = scheduler.tags_csv,
                        .monetary_value = scheduler.monetary_value,
                        .due_at = timestamp,
                    };
                    try zvenc.data.insertAgenda(&db, agenda);
                }
            }
        }
    }

    try zvenc.data.updateLastRunTimeMs(&db, check_date_end.toTimestamp());
}

// Make sure all migrations work fine on a fresh database
test "migrate" {
    const db = try Sqlite3.init(":memory:", .{ .alloc = std.testing.failing_allocator });
    try migrate(db.sqlite3, .{ .emit_debug = true });
}

test {
    std.testing.refAllDecls(@This());
}
