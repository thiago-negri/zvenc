const std = @import("std");
const Date = @import("./Date.zig");

const RuleField = enum {
    year,
    month,
    day,
    week_day,
};

pub const Rule = struct {
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
        var matchers = [_]Matcher{.{ .all = {} }} ** 4;
        errdefer {
            for (matchers) |matcher| {
                matcher.deinit(alloc);
            }
        }

        var matcher_start: usize = 0;
        var opt_matcher_type: ?RuleField = null;
        for (string, 0..) |char, string_index| {
            switch (char) {
                ' ', 'y', 'm', 'd', 'w' => {
                    if (opt_matcher_type) |matcher_type| {
                        const substring = string[matcher_start..string_index];
                        const matcher = try Matcher.parse(substring, alloc);
                        matchers[@intFromEnum(matcher_type)] = matcher;
                    }
                    opt_matcher_type = switch (char) {
                        'y' => .year,
                        'm' => .month,
                        'd' => .day,
                        'w' => .week_day,
                        else => null,
                    };
                    if (char != ' ') {
                        matcher_start = string_index + 1;
                    }
                },
                else => {},
            }
        }
        if (opt_matcher_type) |matcher_type| {
            const substring = string[matcher_start..];
            const matcher = try Matcher.parse(substring, alloc);
            matchers[@intFromEnum(matcher_type)] = matcher;
        }

        const year = matchers[@intFromEnum(RuleField.year)];
        const month = matchers[@intFromEnum(RuleField.month)];
        const day = matchers[@intFromEnum(RuleField.day)];
        const week_day = matchers[@intFromEnum(RuleField.week_day)];

        return Rule.init(year, month, day, week_day);
    }

    test "parse" {
        const rule_all = try Rule.parse("", std.testing.failing_allocator);
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.year));
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.month));
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.day));
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_all.week_day));

        const rule_everything = try Rule.parse("y* m1 d2,3 w-3.-1", std.testing.allocator);
        defer rule_everything.deinit(std.testing.allocator);
        try std.testing.expectEqual(MatcherType.all, @as(MatcherType, rule_everything.year));
        try std.testing.expectEqual(MatcherType.simple, @as(MatcherType, rule_everything.month));
        try std.testing.expectEqual(MatcherType.multi, @as(MatcherType, rule_everything.day));
        try std.testing.expectEqual(MatcherType.range, @as(MatcherType, rule_everything.week_day));
    }

    pub fn matches(self: Rule, date: Date) bool {
        const year_match = self.year.matches(@intFromEnum(date.year));
        const month_match = self.month.matches(@intFromEnum(date.month) + 1);
        const day_match = self.day.matches(@intFromEnum(date.day));
        const negative_day_match = self.day.matches(@intFromEnum(date.day.toNegative(date.year, date.month)));
        const week_day_match = self.week_day.matches(@intFromEnum(date.week_day) + 1);
        return year_match and month_match and (day_match or negative_day_match) and week_day_match;
    }

    test "matches" {
        const now_ts = std.time.timestamp();
        const now = Date.fromTimestamp(now_ts, .utc);

        const TestCase = struct {
            rule: []const u8,
            matches: []const Date,
            skips: []const Date,
        };
        const test_cases: []const TestCase = &[_]TestCase{
            .{
                // Every day
                .rule = "",
                .matches = &[_]Date{
                    now,
                    Date.init(@enumFromInt(2024), .january, @enumFromInt(1), .tuesday),
                },
                .skips = &[0]Date{},
            },
            .{
                // 1st day of every month
                .rule = "d1",
                .matches = &[_]Date{
                    Date.init(@enumFromInt(2024), .january, @enumFromInt(1), .monday),
                    Date.init(@enumFromInt(2024), .february, @enumFromInt(1), .thursday),
                    Date.init(@enumFromInt(2024), .march, @enumFromInt(1), .friday),
                    Date.init(@enumFromInt(2024), .april, @enumFromInt(1), .monday),
                    Date.init(@enumFromInt(2024), .june, @enumFromInt(1), .wednesday),
                    Date.init(@enumFromInt(2024), .july, @enumFromInt(1), .saturday),
                    Date.init(@enumFromInt(2024), .september, @enumFromInt(1), .monday),
                    Date.init(@enumFromInt(2024), .august, @enumFromInt(1), .thursday),
                    Date.init(@enumFromInt(2024), .september, @enumFromInt(1), .sunday),
                    Date.init(@enumFromInt(2024), .october, @enumFromInt(1), .tuesday),
                    Date.init(@enumFromInt(2024), .november, @enumFromInt(1), .friday),
                    Date.init(@enumFromInt(2024), .december, @enumFromInt(1), .sunday),
                },
                .skips = &[_]Date{
                    Date.init(@enumFromInt(2024), .january, @enumFromInt(2), .sunday),
                },
            },
            .{
                // Last Tuesday of every month
                .rule = "d-7.-1w3",
                .matches = &[_]Date{
                    Date.init(@enumFromInt(2024), .january, @enumFromInt(30), .tuesday),
                    Date.init(@enumFromInt(2024), .february, @enumFromInt(27), .tuesday),
                },
                .skips = &[_]Date{
                    Date.init(@enumFromInt(2024), .january, @enumFromInt(23), .tuesday),
                    Date.init(@enumFromInt(2024), .january, @enumFromInt(29), .monday),
                    Date.init(@enumFromInt(2024), .january, @enumFromInt(31), .wednesday),
                    Date.init(@enumFromInt(2024), .february, @enumFromInt(20), .tuesday),
                },
            },
        };

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
        if (string.len == 1 and string[0] == '*') {
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

        const match_type: MatcherType = blk: {
            if (multi_count > 1) {
                break :blk .multi;
            } else if (opt_range_index != null) {
                break :blk .range;
            } else {
                break :blk .simple;
            }
        };

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
        const match_all = try Matcher.parse("*", std.testing.failing_allocator);
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

    pub fn matches(self: Matcher, number: i32) bool {
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

test {
    std.testing.refAllDecls(@This());
}
