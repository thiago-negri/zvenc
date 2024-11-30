const std = @import("std");
const expect = std.testing.expect;

pub const Match = union(enum) { all: void, simple: i16, range: [2]i16, multi: []i16 };

pub const Rule = struct { year: Match, month: Match, day: Match, week_day: Match };

const Year = u14;
const Month = u4;
const Day = u5;
const NegativeDay = i6;

pub const Date = struct {
    year: Year,
    month: Month,
    day: Day,

    pub fn init(year: Year, month: Month, day: Day) Date {
        return Date{ .year = year, .month = month, .day = day };
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

        return .{ .year = year, .month = month, .day = day };
    }

    test "fromTimestamp" {
        try expect(Date.fromTimestamp(1732927932).compare(Date.init(2024, 11, 30)) == .eq);
    }

    pub fn negativeDay(self: Date) NegativeDay {
        return @as(NegativeDay, self.day) - lastDayOfMonth(self.year, self.month) - 1;
    }

    test "negativeDay" {
        try expect(Date.init(2024, 2, 28).negativeDay() == -2);
        try expect(Date.init(2024, 2, 29).negativeDay() == -1);
        try expect(Date.init(2025, 2, 28).negativeDay() == -1);
        try expect(Date.init(2024, 1, 28).negativeDay() == -4);
    }

    pub fn compare(self: Date, other: Date) std.math.Order {
        const this = (@as(i32, self.year) * 12 + @as(i32, self.month)) * 31 + @as(i32, self.day);
        const them = (@as(i32, other.year) * 12 + @as(i32, other.month)) * 31 + @as(i32, other.day);
        return std.math.order(this, them);
    }

    test "compare" {
        try expect(Date.init(2024, 1, 1).compare(Date.init(2025, 1, 1)) == .lt);
        try expect(Date.init(2024, 1, 1).compare(Date.init(2024, 2, 1)) == .lt);
        try expect(Date.init(2024, 1, 1).compare(Date.init(2024, 1, 2)) == .lt);
        try expect(Date.init(2024, 1, 1).compare(Date.init(2024, 1, 1)) == .eq);
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

fn lastDayOfMonth(year: u16, month: u8) u5 {
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
