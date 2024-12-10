const Date = @This();

const std = @import("std");

/// TimeZone in minutes
const Timezone = enum(i12) {
    brazil = -180,
    utc = 0,
};

const Year = enum(u16) {
    _,

    pub inline fn next(self: Year) Year {
        return @enumFromInt(@intFromEnum(self) + 1);
    }
};

const Month = enum {
    january,
    february,
    march,
    april,
    may,
    june,
    july,
    august,
    september,
    october,
    november,
    december,

    pub inline fn next(self: Month) Month {
        return switch (self) {
            .january => .february,
            .february => .march,
            .march => .april,
            .april => .may,
            .may => .june,
            .june => .july,
            .july => .august,
            .august => .september,
            .september => .october,
            .october => .november,
            .november => .december,
            .december => .january,
        };
    }
};

const Day = enum(u5) {
    _,

    pub inline fn compare(self: Day, other: Day) std.math.Order {
        return std.math.order(@intFromEnum(self), @intFromEnum(other));
    }

    pub inline fn next(self: Day) Day {
        return @enumFromInt(@intFromEnum(self) + 1);
    }

    pub inline fn toNegative(self: Day, year: Year, month: Month) NegativeDay {
        return @enumFromInt(@as(i6, @intFromEnum(self)) - @intFromEnum(lastDayOfMonth(year, month)) - 1);
    }

    test "toNegative" {
        try std.testing.expectEqual(
            @as(NegativeDay, @enumFromInt(-2)),
            @as(Day, @enumFromInt(28)).toNegative(@as(Year, @enumFromInt(2024)), .february),
        );
        try std.testing.expectEqual(
            @as(NegativeDay, @enumFromInt(-1)),
            @as(Day, @enumFromInt(29)).toNegative(@as(Year, @enumFromInt(2024)), .february),
        );
        try std.testing.expectEqual(
            @as(NegativeDay, @enumFromInt(-1)),
            @as(Day, @enumFromInt(28)).toNegative(@as(Year, @enumFromInt(2025)), .february),
        );
        try std.testing.expectEqual(
            @as(NegativeDay, @enumFromInt(-4)),
            @as(Day, @enumFromInt(28)).toNegative(@as(Year, @enumFromInt(2024)), .january),
        );
    }
};

const NegativeDay = enum(i6) {
    _,
};

const WeekDay = enum {
    sunday,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,

    pub fn next(self: WeekDay) WeekDay {
        return switch (self) {
            .sunday => .monday,
            .monday => .tuesday,
            .tuesday => .wednesday,
            .wednesday => .thursday,
            .thursday => .friday,
            .friday => .saturday,
            .saturday => .sunday,
        };
    }
};

year: Year,
month: Month,
day: Day,
week_day: WeekDay,

pub fn init(year: Year, month: Month, day: Day, week_day: WeekDay) Date {
    return Date{
        .year = year,
        .month = month,
        .day = day,
        .week_day = week_day,
    };
}

pub fn fromInts(year: u14, month: u4, day: u5, week_day: u4) Date {
    return Date{
        .year = @enumFromInt(year),
        .month = @enumFromInt(month - 1),
        .day = @enumFromInt(day),
        .week_day = @enumFromInt(week_day - 1),
    };
}

pub fn fromTimestamp(timestamp_utc: i64, timezone: Timezone) Date {
    const secs_per_minute: i64 = 60;
    const timestamp = timestamp_utc + @intFromEnum(timezone) * secs_per_minute;

    // https://howardhinnant.github.io/date_algorithms.html#civil_from_days
    const z = @divTrunc(timestamp, std.time.epoch.secs_per_day) + 719468;
    const era = @divTrunc(if (z >= 0) z else z - 146096, 146097);
    const doe = (z - era * 146097);
    const yoe = @divTrunc(doe - @divTrunc(doe, 1460) + @divTrunc(doe, 36524) - @divTrunc(doe, 146096), 365);
    const y = yoe + era * 400;
    const doy = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
    const mp = @divTrunc(5 * doy + 2, 153);
    const d = doy - @divTrunc(153 * mp + 2, 5) + 1;
    const m = if (mp < 10) mp + 3 else mp - 9;

    const year: Year = @enumFromInt(if (m <= 2) y + 1 else y);
    const month: Month = @enumFromInt(m - 1);
    const day: Day = @enumFromInt(d);
    const week_day: WeekDay = @enumFromInt(@mod(z + 2, 7));

    return .{ .year = year, .month = month, .day = day, .week_day = week_day };
}

test "fromTimestamp" {
    try std.testing.expectEqual(.eq, Date.fromTimestamp(1732927932, .utc).compare(Date.fromInts(2024, 11, 30, 6)));
}

inline fn hash(self: Date) i32 {
    return (@as(i32, @intFromEnum(self.year)) * 11 +
        @intFromEnum(self.month)) * 31 +
        @intFromEnum(self.day);
}

pub fn compare(self: Date, other: Date) std.math.Order {
    return std.math.order(self.hash(), other.hash());
}

test "compare" {
    try std.testing.expectEqual(.lt, Date.fromInts(2024, 1, 1, 2).compare(Date.fromInts(2025, 1, 1, 6)));
    try std.testing.expectEqual(.lt, Date.fromInts(2024, 1, 1, 2).compare(Date.fromInts(2024, 2, 1, 5)));
    try std.testing.expectEqual(.lt, Date.fromInts(2024, 1, 1, 2).compare(Date.fromInts(2024, 1, 2, 3)));
    try std.testing.expectEqual(.eq, Date.fromInts(2024, 1, 1, 2).compare(Date.fromInts(2024, 1, 1, 2)));
}

pub fn nextDate(self: Date) Date {
    const next_week_day = self.week_day.next();

    const last_day_of_month = lastDayOfMonth(self.year, self.month);
    const before_last_day_of_month = self.day.compare(last_day_of_month) == .lt;
    if (before_last_day_of_month) {
        return Date.init(self.year, self.month, self.day.next(), next_week_day);
    }

    const next_month = self.month.next();
    if (next_month != .january) {
        return Date.init(self.year, next_month, @enumFromInt(1), next_week_day);
    }

    return Date.init(self.year.next(), .january, @enumFromInt(1), next_week_day);
}

test "nextDay" {
    try std.testing.expectEqual(
        .eq,
        Date.fromInts(2024, 2, 29, 4).compare(Date.fromInts(2024, 2, 28, 4).nextDate()),
    );
    try std.testing.expectEqual(
        .eq,
        Date.fromInts(2024, 3, 1, 5).compare(Date.fromInts(2024, 2, 29, 5).nextDate()),
    );
    try std.testing.expectEqual(
        .eq,
        Date.fromInts(2024, 12, 1, 1).compare(Date.fromInts(2024, 11, 30, 7).nextDate()),
    );
    try std.testing.expectEqual(
        .eq,
        Date.fromInts(2025, 1, 1, 4).compare(Date.fromInts(2024, 12, 31, 3).nextDate()),
    );
}

// https://howardhinnant.github.io/date_algorithms.html#days_from_civil
fn dateToTimestamp(date: Date) i64 {
    var y = @intFromEnum(date.year);
    const m = @intFromEnum(date.month);
    const d = @intFromEnum(date.day);
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

fn isLeapYear(year: Year) bool {
    const y = @intFromEnum(year);
    return y % 4 == 0 and y % 100 != 0;
}

test "isLeapYear" {
    try std.testing.expectEqual(false, isLeapYear(@as(Year, @enumFromInt(2023))));
    try std.testing.expectEqual(true, isLeapYear(@as(Year, @enumFromInt(2024))));
    try std.testing.expectEqual(false, isLeapYear(@as(Year, @enumFromInt(2025))));
    try std.testing.expectEqual(false, isLeapYear(@as(Year, @enumFromInt(2026))));
    try std.testing.expectEqual(false, isLeapYear(@as(Year, @enumFromInt(2027))));
    try std.testing.expectEqual(true, isLeapYear(@as(Year, @enumFromInt(2028))));
    try std.testing.expectEqual(false, isLeapYear(@as(Year, @enumFromInt(2400))));
}

pub fn lastDayOfMonth(year: Year, month: Month) Day {
    switch (month) {
        .january, .march, .may, .july, .august, .october, .december => {
            return @enumFromInt(31);
        },
        .april, .june, .september, .november => {
            return @enumFromInt(30);
        },
        .february => {
            if (isLeapYear(year)) {
                return @enumFromInt(29);
            }
            return @enumFromInt(28);
        },
    }
}

test "lastDayOfMonth" {
    try std.testing.expectEqual(@as(Day, @enumFromInt(31)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .january));
    try std.testing.expectEqual(@as(Day, @enumFromInt(29)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .february));
    try std.testing.expectEqual(@as(Day, @enumFromInt(31)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .march));
    try std.testing.expectEqual(@as(Day, @enumFromInt(30)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .april));
    try std.testing.expectEqual(@as(Day, @enumFromInt(31)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .may));
    try std.testing.expectEqual(@as(Day, @enumFromInt(30)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .june));
    try std.testing.expectEqual(@as(Day, @enumFromInt(31)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .july));
    try std.testing.expectEqual(@as(Day, @enumFromInt(31)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .august));
    try std.testing.expectEqual(@as(Day, @enumFromInt(30)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .september));
    try std.testing.expectEqual(@as(Day, @enumFromInt(31)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .october));
    try std.testing.expectEqual(@as(Day, @enumFromInt(30)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .november));
    try std.testing.expectEqual(@as(Day, @enumFromInt(31)), lastDayOfMonth(@as(Year, @enumFromInt(2024)), .december));
    try std.testing.expectEqual(@as(Day, @enumFromInt(28)), lastDayOfMonth(@as(Year, @enumFromInt(2025)), .february));
}
