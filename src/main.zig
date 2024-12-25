const std = @import("std");

const migrate = @import("zsqlite-migrate").migrate;
const Sqlite3 = @import("zsqlite").Sqlite3;

const AgendaInsert = @import("AgendaInsert.zig");
const data = @import("data.zig");
const Date = @import("Date.zig");
const Scheduler = @import("Scheduler.zig");
const SchedulerInsert = @import("SchedulerInsert.zig");

const Gpa = std.heap.GeneralPurposeAllocator(.{});

const db_filename = "zvenc.db";
const my_timezone = .brazil;

pub fn main() !void {
    var gpa = Gpa{};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Connect to database
    var db = Sqlite3.init(db_filename, .{ .alloc = alloc }) catch |err| {
        std.debug.print("Failed to connect to SQLite", .{});
        return err;
    };
    defer db.deinit();

    // Migrate the database
    migrate(db.sqlite3, .{ .emit_debug = true }) catch |err| {
        db.printError("migrate");
        return err;
    };

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    // Skip executable name
    _ = args.skip();

    const command = args.next() orelse "run";

    // Command: run
    if (std.mem.eql(u8, command, "run")) {
        try run(&db, alloc);
        return;
    }

    // Command: scheduler
    if (std.mem.eql(u8, command, "scheduler")) {
        const sub_command = args.next() orelse "list";
        if (std.mem.eql(u8, sub_command, "list")) {
            try schedulerList(&db, alloc);
            return;
        }
        if (std.mem.eql(u8, sub_command, "rm")) {
            try schedulerDelete(&db, &args);
            return;
        }
        if (std.mem.eql(u8, sub_command, "add")) {
            try schedulerAdd(&db, &args);
            // TODO: Rerun scheduler
            return;
        }
    }

    // Command: Agenda
    if (std.mem.eql(u8, command, "agenda")) {
        const sub_command = args.next() orelse "list";
        if (std.mem.eql(u8, sub_command, "list")) {
            try agendaList(&db);
            return;
        }
        if (std.mem.eql(u8, sub_command, "rm")) {
            try agendaDelete(&db, &args);
            return;
        }
        if (std.mem.eql(u8, sub_command, "add")) {
            try agendaAdd(&db, &args);
            return;
        }
    }

    // Ideas for commands:
    // - scheduler list (DONE)
    // - scheduler rm <id> (DONE)
    // - agenda list (DONE)
    // - agenda rm <id> (DONE)
    // - scheduler add <rule> <description> <tags> <monetary_value> (DONE)
    // - agenda add <due> <description> <tags> <monetary_value> (DONE)
    //
    // - scheduler edit <id> <rule> <description> <tags> <monetary_value>
    // - agenda edit <id> <due> <description> <tags> <monetary_value>
    //
    // Default command runs the scheduler and list due entries
    // Add a filter by tags for "list" commands, and also a "project" to extract only some fields
    // This would allow to pipe the results into other CLIs
}

/// run
fn run(db: *Sqlite3, alloc: std.mem.Allocator) !void {
    try schedulerPopulate(db, alloc);
    try agendaListDue(db);
}

fn agendaListDue(db: *Sqlite3) !void {
    const now = std.time.timestamp();
    const today = Date.fromTimestamp(now, .utc);
    std.debug.print("TODAY: {d}/{d}/{d} {any}\n", .{
        @intFromEnum(today.year),
        @intFromEnum(today.month) + 1,
        @intFromEnum(today.day),
        today.week_day,
    });

    const iter = try data.listAgenda(db);
    defer iter.deinit();

    while (try iter.next()) |agenda| {
        const date = Date.fromTimestamp(agenda.due_at, .utc);
        const compare = date.compare(today);
        if (compare != .gt) {
            std.debug.print("Due -- {d}/{d}/{d} {s}\n", .{
                @intFromEnum(date.year),
                @intFromEnum(date.month) + 1,
                @intFromEnum(date.day),
                agenda.description,
            });
        }
    }
}

/// Will loop over all Scheduler rows and generate Agenda entries for missing ones
fn schedulerPopulate(db: *Sqlite3, alloc: std.mem.Allocator) !void {
    const now = std.time.timestamp();
    const today = Date.fromTimestamp(now, my_timezone);

    const last_run = try data.selectLastRunTimeMs(db);

    const check_date_start = if (last_run) |date|
        Date.fromTimestamp(date, .utc).nextDate()
    else
        Date.fromTimestamp(now, my_timezone);

    const check_date_end = today.addDays(60);

    const rules_count = try data.countScheduler(db);

    var scheduler_list = try std.ArrayList(Scheduler).initCapacity(alloc, rules_count);
    defer {
        for (scheduler_list.items) |item| {
            item.deinit(alloc);
        }
        scheduler_list.deinit();
    }

    // Populate scheduler_list
    {
        const iter = try data.listScheduler(db);
        defer iter.deinit();
        while (try iter.next(alloc)) |row| {
            errdefer row.deinit(alloc);
            try scheduler_list.append(row);
        }
    }

    // Loop through all dates
    var check_date = check_date_start;
    while (check_date.compare(check_date_end) != .gt) : (check_date = check_date.nextDate()) {
        const timestamp = check_date.toTimestamp();
        for (scheduler_list.items) |scheduler| {
            const match = scheduler.rule_parsed.matches(check_date);
            if (match) {
                const exists = try data.existsAgenda(db, scheduler.id, timestamp);
                if (!exists) {
                    // Generate an entry
                    const agenda = AgendaInsert{
                        .scheduler_id = scheduler.id,
                        .description = scheduler.description,
                        .tags_csv = scheduler.tags_csv,
                        .monetary_value = scheduler.monetary_value,
                        .due_at = timestamp,
                    };
                    try data.insertAgenda(db, agenda);
                }
            }
        }
    }

    // Update last run
    try data.updateLastRunTimeMs(db, check_date_end.toTimestamp());
}

/// agenda list
fn agendaList(db: *Sqlite3) !void {
    const iter = try data.listAgenda(db);
    defer iter.deinit();

    while (try iter.next()) |agenda| {
        const date = Date.fromTimestamp(agenda.due_at, .utc);
        std.debug.print("{d}: {d}/{d}/{d} {s}\n", .{
            agenda.id,
            @intFromEnum(date.year),
            @intFromEnum(date.month) + 1,
            @intFromEnum(date.day),
            agenda.description,
        });
    }
}

/// agenda rm <id>
fn agendaDelete(db: *Sqlite3, args: *std.process.ArgIterator) !void {
    const agenda_id_raw = args.next() orelse return error.MissingAgendaId;
    const agenda_id = try std.fmt.parseInt(i64, agenda_id_raw, 10);
    try data.deleteAgenda(db, agenda_id);
}

/// agenda add <due> <description> <tags> <monetary_value>
fn agendaAdd(db: *Sqlite3, args: *std.process.ArgIterator) !void {
    const due = args.next() orelse return error.MissingDue;
    const description = args.next() orelse return error.MissingDescription;
    const tags = args.next() orelse return error.MissingTags;
    const monetary_value = try std.fmt.parseInt(i64, args.next() orelse return error.MissingMonetaryValue, 10);
    const due_at = try parseTimestamp(due);
    const agenda_insert = AgendaInsert{
        .due_at = due_at,
        .description = description,
        .tags_csv = tags,
        .monetary_value = monetary_value,
        .scheduler_id = null,
    };
    try data.insertAgenda(db, agenda_insert);
}

/// Parse a date in format YYYY-MM-DD into a timestamp
fn parseTimestamp(date: []const u8) !i64 {
    if (date.len != 10 or date[4] != '-' or date[7] != '-') return error.IncorrectDateFormat;
    const year = try std.fmt.parseInt(u14, date[0..4], 10);
    const month = try std.fmt.parseInt(u4, date[5..7], 10);
    const day = try std.fmt.parseInt(u5, date[8..10], 10);
    const week_day = 1; // Week day is not relevant
    return Date.fromInts(year, month, day, week_day).toTimestamp();
}

/// scheduler list
fn schedulerList(db: *Sqlite3, alloc: std.mem.Allocator) !void {
    const iter = try data.listScheduler(db);
    defer iter.deinit();

    while (try iter.next(alloc)) |scheduler| {
        defer scheduler.deinit(alloc);
        std.debug.print("{d}: {s} ({s})\n", .{ scheduler.id, scheduler.description, scheduler.rule });
    }
}

/// scheduler rm <id>
fn schedulerDelete(db: *Sqlite3, args: *std.process.ArgIterator) !void {
    const scheduler_id_raw = args.next() orelse return error.MissingSchedulerId;
    const scheduler_id = try std.fmt.parseInt(i64, scheduler_id_raw, 10);
    try data.deleteScheduler(db, scheduler_id);
}

/// scheduler add <rule> <description> <tags> <monetary_value>
fn schedulerAdd(db: *Sqlite3, args: *std.process.ArgIterator) !void {
    const rule = args.next() orelse return error.MissingRule;
    const description = args.next() orelse return error.MissingDescription;
    const tags = args.next() orelse return error.MissingTags;
    const monetary_value = try std.fmt.parseInt(i64, args.next() orelse return error.MissingMonetaryValue, 10);
    const scheduler_insert = SchedulerInsert{
        .rule = rule,
        .description = description,
        .tags_csv = tags,
        .monetary_value = monetary_value,
    };
    try data.insertScheduler(db, scheduler_insert);
}

// Make sure all migrations work fine on a fresh database
test "migrate" {
    const db = try Sqlite3.init(":memory:", .{ .alloc = std.testing.failing_allocator });
    try migrate(db.sqlite3, .{ .emit_debug = true });
}

test {
    std.testing.refAllDecls(@This());
}
