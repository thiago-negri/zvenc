const zsqlite = @import("zsqlite");
const embedMinifiedSql = @import("zsqlite-minify").embedMinifiedSql;

pub const SchedulerRule = struct {
    id: i64,
    rule: []const u8,

    pub fn init(row: zsqlite.Row) SchedulerRule {
        const id = row.column(0, i64);
        const rule = row.columnTextPtr(1);
        return SchedulerRule{ .id = id, .rule = rule };
    }
};

const SchedulerRuleStatement = zsqlite.StatementIterator(
    SchedulerRule,
    SchedulerRule.init,
    embedMinifiedSql("sqls/scheduler_select.sql"),
);

pub fn selectSchedulerRules(db: zsqlite.Sqlite3) !SchedulerRuleStatement {
    return SchedulerRuleStatement.prepare(db);
}

pub fn selectLastRunTimeMs(db: zsqlite.Sqlite3) !?i64 {
    const stmt = try db.prepare(embedMinifiedSql("sqls/scheduler_control_select.sql"));
    if (try stmt.step()) |row| {
        const last_run_time = row.column(0, i64);
        return last_run_time;
    }
    return null;
}
