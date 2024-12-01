const zsqlite = @import("zsqlite");

pub const SchedulerRule = struct { id: i64, rule: []const u8 };

pub fn StmtIterator(Item: type, comptime extractor: fn (row: zsqlite.Row) Item) type {
    return struct {
        stmt: zsqlite.Statement,

        const Self = @This();

        pub fn init(stmt: zsqlite.Statement) Self {
            return Self{ .stmt = stmt };
        }

        pub fn deinit(self: Self) void {
            self.stmt.deinit();
        }

        pub fn next(self: Self) !?Item {
            if (try self.stmt.step()) |row| {
                return extractor(row);
            }
            return null;
        }
    };
}

fn schedulerRuleExtractor(row: zsqlite.Row) SchedulerRule {
    const id = row.column(0, i64);
    const rule = row.columnTextPtr(1);
    return SchedulerRule{ .id = id, .rule = rule };
}

const SchedulerRuleExtractor = StmtIterator(SchedulerRule, schedulerRuleExtractor);

pub fn selectSchedulerRules(db: zsqlite.Sqlite3) !SchedulerRuleExtractor {
    const stmt = try db.prepare("SELECT id, rule FROM scheduler");
    return SchedulerRuleExtractor.init(stmt);
}
