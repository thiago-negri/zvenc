const AgendaInsert = @import("AgendaInsert.zig");
const embedMinifiedSql = @import("zsqlite-minify").embedMinifiedSql;
const Scheduler = @import("Scheduler.zig");
const std = @import("std");
const zsqlite = @import("zsqlite");

const SchedulerRuleStatement = zsqlite.StatementIteratorAlloc(
    Scheduler,
    std.fmt.ParseIntError || std.mem.Allocator.Error,
    Scheduler.init,
    embedMinifiedSql("sqls/scheduler_select.sql"),
);

pub fn selectSchedulerRulesCount(db: *zsqlite.Sqlite3) !u64 {
    const stmt = try db.prepare(embedMinifiedSql("sqls/scheduler_count.sql"));
    defer stmt.deinit();
    const opt_row = try stmt.step();
    if (opt_row) |row| {
        const count = row.column(0, i64);
        return @intCast(count);
    }
    return 0;
}

pub fn selectSchedulerRules(db: *zsqlite.Sqlite3) !SchedulerRuleStatement {
    return SchedulerRuleStatement.prepare(db);
}

pub fn selectLastRunTimeMs(db: *zsqlite.Sqlite3) !?i64 {
    const stmt = try db.prepare(embedMinifiedSql("sqls/scheduler_control_select.sql"));
    defer stmt.deinit();
    if (try stmt.step()) |row| {
        const last_run_time = row.column(0, i64);
        return last_run_time;
    }
    return null;
}

pub fn updateLastRunTimeMs(db: *zsqlite.Sqlite3, timestamp: i64) !void {
    const stmt = try db.prepare(embedMinifiedSql("sqls/scheduler_control_update.sql"));
    defer stmt.deinit();
    try stmt.bind(1, timestamp);
    try stmt.exec();
}

pub fn insertAgenda(db: *zsqlite.Sqlite3, agenda: AgendaInsert) !void {
    const stmt = try db.prepare(embedMinifiedSql("sqls/agenda_insert.sql"));
    defer stmt.deinit();
    try stmt.bind(1, agenda.scheduler_id);
    try stmt.bindText(2, agenda.description);
    try stmt.bindText(3, agenda.tags_csv);
    try stmt.bind(4, agenda.monetary_value);
    try stmt.bind(5, agenda.due_at);
    try stmt.exec();
}
