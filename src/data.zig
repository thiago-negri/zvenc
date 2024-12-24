const Agenda = @import("Agenda.zig");
const AgendaInsert = @import("AgendaInsert.zig");
const embedMinifiedSql = @import("zsqlite-minify").embedMinifiedSql;
const Scheduler = @import("Scheduler.zig");
const std = @import("std");
const zsqlite = @import("zsqlite");

const SchedulerIterator = zsqlite.StatementIteratorAlloc(
    Scheduler,
    std.fmt.ParseIntError || std.mem.Allocator.Error,
    Scheduler.init,
    embedMinifiedSql("sqls/scheduler_list.sql"),
);

const AgendaIterator = zsqlite.StatementIterator(
    Agenda,
    Agenda.init,
    embedMinifiedSql("sqls/agenda_list.sql"),
);

pub fn countScheduler(db: *zsqlite.Sqlite3) !u64 {
    const stmt = try db.prepare(embedMinifiedSql("sqls/scheduler_count.sql"));
    defer stmt.deinit();
    const opt_row = try stmt.step();
    if (opt_row) |row| {
        const count = row.column(0, i64);
        return @intCast(count);
    }
    return 0;
}

pub fn listScheduler(db: *zsqlite.Sqlite3) !SchedulerIterator {
    return SchedulerIterator.prepare(db);
}

pub fn deleteScheduler(db: *zsqlite.Sqlite3, scheduler_id: i64) !void {
    const archived_at = std.time.timestamp();

    // Insert the scheduler_archive row
    const archive_stmt = try db.prepare(embedMinifiedSql("sqls/scheduler_archive.sql"));
    defer archive_stmt.deinit();
    try archive_stmt.bind(1, archived_at);
    try archive_stmt.bind(2, scheduler_id);
    const row = try archive_stmt.step() orelse return error.NotFound;
    const scheduler_archive_id = row.column(0, i64);

    // Change all agenda entries to point to the archived scheduler
    const agenda_update_stmt = try db.prepare(embedMinifiedSql("sqls/agenda_update_scheduler_archive.sql"));
    defer agenda_update_stmt.deinit();
    try agenda_update_stmt.bind(1, scheduler_archive_id);
    try agenda_update_stmt.bind(2, scheduler_id);
    try agenda_update_stmt.exec();

    // Change all archived agenda entries to point to the archived scheduler
    const agenda_archive_update_stmt = try db.prepare(embedMinifiedSql("sqls/agenda_archive_update_scheduler_archive.sql"));
    defer agenda_archive_update_stmt.deinit();
    try agenda_archive_update_stmt.bind(1, scheduler_archive_id);
    try agenda_archive_update_stmt.bind(2, scheduler_id);
    try agenda_archive_update_stmt.exec();

    // Delete the scheduler row
    const delete_stmt = try db.prepare(embedMinifiedSql("sqls/scheduler_delete.sql"));
    defer delete_stmt.deinit();
    try delete_stmt.bind(1, scheduler_id);
    try delete_stmt.exec();
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

pub fn existsAgenda(db: *zsqlite.Sqlite3, scheduler_id: i64, due_at: i64) !bool {
    const stmt = try db.prepare(embedMinifiedSql("sqls/agenda_exists.sql"));
    defer stmt.deinit();
    try stmt.bind(1, scheduler_id);
    try stmt.bind(2, due_at);
    const row = try stmt.step();
    return row != null;
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

pub fn listAgenda(db: *zsqlite.Sqlite3) !AgendaIterator {
    return AgendaIterator.prepare(db);
}

pub fn deleteAgenda(db: *zsqlite.Sqlite3, agenda_id: i64) !void {
    const archived_at = std.time.timestamp();

    // Insert the agenda_archive row
    const archive_stmt = try db.prepare(embedMinifiedSql("sqls/agenda_archive.sql"));
    defer archive_stmt.deinit();
    try archive_stmt.bind(1, archived_at);
    try archive_stmt.bind(2, agenda_id);
    try archive_stmt.exec();

    // Delete the agenda row
    const delete_stmt = try db.prepare(embedMinifiedSql("sqls/agenda_delete.sql"));
    defer delete_stmt.deinit();
    try delete_stmt.bind(1, agenda_id);
    try delete_stmt.exec();
}
