const std = @import("std");

const Year = u14;
const Month = u4;
const Day = u5;
const NegativeDay = i6;
const WeekDay = u4;

pub const Date = struct {
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

    pub fn negativeDay(self: Date) NegativeDay {
        const day = self.day;
        const month = self.month;
        const year = self.year;
        return @as(NegativeDay, day) - lastDayOfMonth(year, month) - 1;
    }

    test "negativeDay" {
        try std.testing.expectEqual(-2, Date.init(2024, 2, 28, 1).negativeDay());
        try std.testing.expectEqual(-1, Date.init(2024, 2, 29, 1).negativeDay());
        try std.testing.expectEqual(-1, Date.init(2025, 2, 28, 1).negativeDay());
        try std.testing.expectEqual(-4, Date.init(2024, 1, 28, 1).negativeDay());
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

pub fn lastDayOfMonth(year: Year, month: Month) Day {
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
