const std = @import("std");
const Sqlite3 = @import("zsqlite").Sqlite3;
const migrate = @import("zsqlite-migrate").migrate;

const print = std.debug.print;

pub fn main() !void {
    const db = Sqlite3.init("zvenc.db") catch |err| {
        print("Failed to connect to SQLite", .{});
        return err;
    };
    defer db.deinit();

    {
        errdefer db.printError("migrate");
        try migrate(db.sqlite3);
    }

    const now = Date.fromTimestamp(std.time.timestamp());
    std.debug.print("Today is {any}\n", .{now});
}

const MatcherType = enum { all, simple, range, multi };

const Matcher = union(MatcherType) {
    all,
    simple: i16,
    range: [2]i16,
    multi: []const Matcher,

    pub fn deinit(self: Matcher, alloc: std.mem.Allocator) void {
        switch (self) {
            .multi => |multi| {
                alloc.free(multi);
            },
            else => {},
        }
    }

    pub fn parse(string: []const u8, alloc: std.mem.Allocator) !Matcher {
        if (string.len == 1 and string[0] == '_') {
            return Matcher{ .all = {} };
        }

        var opt_range_index: ?usize = null;
        var multi_count: usize = 1;

        for (string, 0..) |char, index| {
            if (char == ',') {
                multi_count += 1;
            }
            if (char == '.') {
                opt_range_index = index;
            }
        }

        const match_type: MatcherType = if (multi_count > 1) .multi else if (opt_range_index != null) .range else .simple;

        switch (match_type) {
            .all => unreachable,
            .simple => {
                const number = try std.fmt.parseInt(i16, string, 10);
                return Matcher{ .simple = number };
            },
            .range => {
                const range_index = opt_range_index.?;
                const string_before = string[0..range_index];
                const string_after = string[range_index + 1 ..];
                const lhs = try std.fmt.parseInt(i16, string_before, 10);
                const rhs = try std.fmt.parseInt(i16, string_after, 10);
                return Matcher{ .range = .{ lhs, rhs } };
            },
            .multi => {
                const sub_matchers = try alloc.alloc(Matcher, multi_count);
                errdefer alloc.free(sub_matchers);
                var sub_index: usize = 0;
                var start_index: usize = 0;
                for (string, 0..) |char, string_index| {
                    if (char == ',') {
                        const substring = string[start_index..string_index];
                        start_index = string_index + 1;
                        sub_matchers[sub_index] = try Matcher.parse(substring, alloc);
                        sub_index += 1;
                    }
                }
                const substring = string[start_index..];
                sub_matchers[sub_index] = try Matcher.parse(substring, alloc);
                return Matcher{ .multi = sub_matchers };
            },
        }
    }

    test "parse" {
        const match_all = try Matcher.parse("_", std.testing.failing_allocator);
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, match_all));

        const match_simple = try Matcher.parse("42", std.testing.failing_allocator);
        try std.testing.expectEqual(MatcherType.simple, @as(MatcherType, match_simple));
        try std.testing.expectEqual(42, match_simple.simple);

        const match_range = try Matcher.parse("3.7", std.testing.failing_allocator);
        try std.testing.expectEqual(MatcherType.range, @as(MatcherType, match_range));
        try std.testing.expectEqual(3, match_range.range[0]);
        try std.testing.expectEqual(7, match_range.range[1]);

        const match_multi = try Matcher.parse("1,4.8,-3", std.testing.allocator);
        defer match_multi.deinit(std.testing.allocator);
        try std.testing.expectEqual(MatcherType.multi, @as(MatcherType, match_multi));
        try std.testing.expectEqual(MatcherType.simple, @as(MatcherType, match_multi.multi[0]));
        try std.testing.expectEqual(1, match_multi.multi[0].simple);
        try std.testing.expectEqual(MatcherType.range, @as(MatcherType, match_multi.multi[1]));
        try std.testing.expectEqual(4, match_multi.multi[1].range[0]);
        try std.testing.expectEqual(8, match_multi.multi[1].range[1]);
        try std.testing.expectEqual(MatcherType.simple, @as(MatcherType, match_multi.multi[2]));
        try std.testing.expectEqual(-3, match_multi.multi[2].simple);
    }

    pub fn matches(self: Matcher, number: i33) bool {
        switch (self) {
            .all => return true,
            .simple => |simple| {
                return simple == number;
            },
            .range => |range| {
                return range[0] <= number and number <= range[1];
            },
            .multi => |multi| {
                for (multi) |item| {
                    if (item.matches(number)) {
                        return true;
                    }
                }
                return false;
            },
        }
    }

    test "matches" {
        try std.testing.expect((Matcher{ .all = {} }).matches(2));

        try std.testing.expect((Matcher{ .simple = 5 }).matches(5));
        try std.testing.expect(!(Matcher{ .simple = 5 }).matches(3));

        try std.testing.expect(!(Matcher{ .range = .{ 2, 4 } }).matches(1));
        try std.testing.expect((Matcher{ .range = .{ 2, 4 } }).matches(2));
        try std.testing.expect((Matcher{ .range = .{ 2, 4 } }).matches(3));
        try std.testing.expect((Matcher{ .range = .{ 2, 4 } }).matches(4));
        try std.testing.expect(!(Matcher{ .range = .{ 2, 4 } }).matches(6));

        var multi = [_]Matcher{ .{ .simple = 3 }, .{ .simple = 5 } };
        try std.testing.expect(!(Matcher{ .multi = &multi }).matches(2));
        try std.testing.expect((Matcher{ .multi = &multi }).matches(3));
        try std.testing.expect(!(Matcher{ .multi = &multi }).matches(4));
        try std.testing.expect((Matcher{ .multi = &multi }).matches(5));
        try std.testing.expect(!(Matcher{ .multi = &multi }).matches(6));
    }
};

const Rule = struct {
    year: Matcher,
    month: Matcher,
    day: Matcher,
    week_day: Matcher,

    pub fn deinit(self: Rule, alloc: std.mem.Allocator) void {
        self.year.deinit(alloc);
        self.month.deinit(alloc);
        self.day.deinit(alloc);
        self.week_day.deinit(alloc);
    }

    pub fn init(year: Matcher, month: Matcher, day: Matcher, week_day: Matcher) Rule {
        return Rule{ .year = year, .month = month, .day = day, .week_day = week_day };
    }

    pub fn parse(string: []const u8, alloc: std.mem.Allocator) !Rule {
        var start_index: usize = 0;
        var matchers = [_]Matcher{.{ .all = {} }} ** 4;
        errdefer {
            for (matchers) |matcher| {
                matcher.deinit(alloc);
            }
        }

        var matchers_index: usize = 0;
        for (string, 0..) |char, string_index| {
            if (char == ' ') {
                const substring = string[start_index..string_index];
                start_index = string_index + 1;
                matchers[matchers_index] = try Matcher.parse(substring, alloc);
                matchers_index += 1;
            }
        }
        const substring = string[start_index..];
        matchers[matchers_index] = try Matcher.parse(substring, alloc);

        const year = matchers[0];
        const month = matchers[1];
        const day = matchers[2];
        const week_day = matchers[3];

        return Rule.init(year, month, day, week_day);
    }

    test "parse" {
        const rule_all = try Rule.parse("_", std.testing.failing_allocator);
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.year));
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.month));
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.day));
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.week_day));

        const rule_everything = try Rule.parse("_ 1 2,3 -3.-1", std.testing.allocator);
        defer rule_everything.deinit(std.testing.allocator);
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_everything.year));
        try std.testing.expectEqual(MatcherType.simple, @as(MatcherType, rule_everything.month));
        try std.testing.expectEqual(MatcherType.multi, @as(MatcherType, rule_everything.day));
        try std.testing.expectEqual(MatcherType.range, @as(MatcherType, rule_everything.week_day));
    }

    pub fn matches(self: Rule, date: Date) bool {
        return self.year.matches(date.year) and
            self.month.matches(date.month) and
            (self.day.matches(date.day) or self.day.matches(negativeDay(date.year, date.month, date.day))) and
            self.week_day.matches(date.week_day);
    }

    test "matches" {
        const now_ts = std.time.timestamp();
        const now = Date.fromTimestamp(now_ts);

        // zig fmt: off
        const TestCase = struct {
            rule: []const u8,
            matches: []const Date,
            skips: []const Date
        };
        const test_cases: []const TestCase = &[_]TestCase{
            .{
                // Every day
                .rule = "_",
                .matches = &[_]Date{
                    now,
                    Date.init(2024, 1, 1, 2)
                },
                .skips = &[0]Date{} 
            }, .{
                // 1st day of every month
                .rule = "_ _ 1",
                .matches = &[_]Date{
                    Date.init(2024, 1, 1, 2),
                    Date.init(2024, 2, 1, 5),
                    Date.init(2024, 3, 1, 6),
                    Date.init(2024, 4, 1, 2),
                    Date.init(2024, 5, 1, 4),
                    Date.init(2024, 6, 1, 7),
                    Date.init(2024, 7, 1, 2),
                    Date.init(2024, 8, 1, 5),
                    Date.init(2024, 9, 1, 1),
                    Date.init(2024, 10, 1, 3),
                    Date.init(2024, 11, 1, 6),
                    Date.init(2024, 12, 1, 1)
                },
                .skips = &[_]Date{
                    Date.init(2024, 1, 2, 7),
                }
            }, .{
                // Last Tuesday of every month
                .rule = "_ _ -7.-1 3",
                .matches = &[_]Date{
                    Date.init(2024, 1, 30, 3),
                    Date.init(2024, 2, 27, 3),
                },
                .skips = &[_]Date{
                    Date.init(2024, 1, 23, 3),
                    Date.init(2024, 1, 29, 2),
                    Date.init(2024, 1, 31, 4),
                    Date.init(2024, 2, 20, 3),
                }
            }
        };
        // zig fmt: on

        for (test_cases) |test_case| {
            const rule = try Rule.parse(test_case.rule, std.testing.allocator);
            defer rule.deinit(std.testing.allocator);
            for (test_case.matches) |match| {
                errdefer std.debug.print("Rule '{s}' did not match '{any}'\n", .{ test_case.rule, match });
                try std.testing.expect(rule.matches(match));
            }
            for (test_case.skips) |skip| {
                errdefer std.debug.print("Rule '{s}' did match '{any}'\n", .{ test_case.rule, skip });
                try std.testing.expect(!rule.matches(skip));
            }
        }
    }
};

const Year = u14;
const Month = u4;
const Day = u5;
const NegativeDay = i6;
const WeekDay = u4;

const Date = struct {
    year: Year,
    month: Month,
    day: Day,
    week_day: WeekDay,

    pub fn init(year: Year, month: Month, day: Day, week_day: WeekDay) Date {
        return Date{ .year = year, .month = month, .day = day, .week_day = week_day };
    }

    // https://howardhinnant.github.io/date_algorithms.html#civil_from_days
    pub fn fromTimestamp(timestamp: i64) Date {
        const seconds_in_day = 24 * 60 * 60;
        var z = @divTrunc(timestamp, seconds_in_day);
        z += 719468;
        const era = @divTrunc(if (z >= 0) z else z - 146096, 146097);
        const doe = (z - era * 146097);
        const yoe = @divTrunc(doe - @divTrunc(doe, 1460) + @divTrunc(doe, 36524) - @divTrunc(doe, 146096), 365);
        const y = yoe + era * 400;
        const doy = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
        const mp = @divTrunc(5 * doy + 2, 153);
        const d = doy - @divTrunc(153 * mp + 2, 5) + 1;
        const m = if (mp < 10) mp + 3 else mp - 9;

        const year: Year = @intCast(if (m <= 2) y + 1 else y);
        const month: Month = @intCast(m);
        const day: Day = @intCast(d);
        const week_day: WeekDay = @intCast(1 + @mod(z + 2, @as(WeekDay, 7)));

        return .{ .year = year, .month = month, .day = day, .week_day = week_day };
    }

    test "fromTimestamp" {
        try std.testing.expectEqual(.eq, Date.fromTimestamp(1732927932).compare(Date.init(2024, 11, 30, 6)));
    }

    pub fn compare(self: Date, other: Date) std.math.Order {
        const this = (@as(i32, self.year) * 12 + @as(i32, self.month)) * 31 + @as(i32, self.day);
        const them = (@as(i32, other.year) * 12 + @as(i32, other.month)) * 31 + @as(i32, other.day);
        return std.math.order(this, them);
    }

    test "compare" {
        try std.testing.expectEqual(.lt, Date.init(2024, 1, 1, 2).compare(Date.init(2025, 1, 1, 6)));
        try std.testing.expectEqual(.lt, Date.init(2024, 1, 1, 2).compare(Date.init(2024, 2, 1, 5)));
        try std.testing.expectEqual(.lt, Date.init(2024, 1, 1, 2).compare(Date.init(2024, 1, 2, 3)));
        try std.testing.expectEqual(.eq, Date.init(2024, 1, 1, 2).compare(Date.init(2024, 1, 1, 2)));
    }

    pub fn nextDay(self: Date) Date {
        const before_last_week_day = self.week_day < 7;
        const next_week_day = if (before_last_week_day) self.week_day + 1 else 1;

        const last_day_of_month = lastDayOfMonth(self.year, self.month);
        const before_last_day_of_month = self.day < last_day_of_month;
        if (before_last_day_of_month) {
            return Date.init(self.year, self.month, self.day + 1, next_week_day);
        }

        const before_last_month = self.month < 12;
        if (before_last_month) {
            return Date.init(self.year, self.month + 1, 1, next_week_day);
        }

        return Date.init(self.year + 1, 1, 1, next_week_day);
    }

    test "nextDay" {
        try std.testing.expectEqual(.eq, Date.init(2024, 2, 29, 4).compare(Date.init(2024, 2, 28, 4).nextDay()));
        try std.testing.expectEqual(.eq, Date.init(2024, 3, 1, 5).compare(Date.init(2024, 2, 29, 5).nextDay()));
        try std.testing.expectEqual(.eq, Date.init(2024, 12, 1, 1).compare(Date.init(2024, 11, 30, 7).nextDay()));
        try std.testing.expectEqual(.eq, Date.init(2025, 1, 1, 4).compare(Date.init(2024, 12, 31, 3).nextDay()));
    }
};

// https://howardhinnant.github.io/date_algorithms.html#days_from_civil
fn dateToTimestamp(date: Date) i64 {
    var y = date.year;
    const m = date.month;
    const d = date.day;
    if (m > 2) {
        y -= 1;
    }
    const era = @divTrunc(if (y >= 0) y else y - 399, 400);
    const yoe = y - era * 400;
    const doy = @divTrunc((153 * (if (m > 2) m - 3 else m + 9) + 2), 5) + d - 1;
    const doe = yoe * 365 + @divTrunc(yoe, 4) - @divTrunc(yoe, 100) + doy;
    const seconds_in_day = 24 * 60 * 60;
    return seconds_in_day * (era * 146097 + doe - 719468);
}

fn isLeapYear(year: u16) bool {
    return year % 4 == 0 and year % 100 != 0;
}

test "isLeapYear" {
    try std.testing.expectEqual(false, isLeapYear(2023));
    try std.testing.expectEqual(true, isLeapYear(2024));
    try std.testing.expectEqual(false, isLeapYear(2025));
    try std.testing.expectEqual(false, isLeapYear(2026));
    try std.testing.expectEqual(false, isLeapYear(2027));
    try std.testing.expectEqual(true, isLeapYear(2028));
    try std.testing.expectEqual(false, isLeapYear(2400));
}

fn lastDayOfMonth(year: Year, month: Month) Day {
    switch (month) {
        1, 3, 5, 7, 8, 10, 12 => {
            return 31;
        },
        4, 6, 9, 11 => {
            return 30;
        },
        2 => {
            if (isLeapYear(year)) {
                return 29;
            }
            return 28;
        },
        else => unreachable,
    }
}

test "lastDayOfMonth" {
    try std.testing.expectEqual(31, lastDayOfMonth(2024, 1));
    try std.testing.expectEqual(29, lastDayOfMonth(2024, 2));
    try std.testing.expectEqual(31, lastDayOfMonth(2024, 3));
    try std.testing.expectEqual(30, lastDayOfMonth(2024, 4));
    try std.testing.expectEqual(31, lastDayOfMonth(2024, 5));
    try std.testing.expectEqual(30, lastDayOfMonth(2024, 6));
    try std.testing.expectEqual(31, lastDayOfMonth(2024, 7));
    try std.testing.expectEqual(31, lastDayOfMonth(2024, 8));
    try std.testing.expectEqual(30, lastDayOfMonth(2024, 9));
    try std.testing.expectEqual(31, lastDayOfMonth(2024, 10));
    try std.testing.expectEqual(30, lastDayOfMonth(2024, 11));
    try std.testing.expectEqual(31, lastDayOfMonth(2024, 12));

    try std.testing.expectEqual(28, lastDayOfMonth(2025, 2));
}

pub fn negativeDay(year: Year, month: Month, day: Day) NegativeDay {
    return @as(NegativeDay, day) - lastDayOfMonth(year, month) - 1;
}

test "negativeDay" {
    try std.testing.expectEqual(-2, negativeDay(2024, 2, 28));
    try std.testing.expectEqual(-1, negativeDay(2024, 2, 29));
    try std.testing.expectEqual(-1, negativeDay(2025, 2, 28));
    try std.testing.expectEqual(-4, negativeDay(2024, 1, 28));
}

test {
    std.testing.refAllDecls(@This());
}
