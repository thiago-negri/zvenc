pub const Match = union(enum) { all: void, simple: i16, range: [2]i16, multi: []i16 };

pub const Rule = struct { year: Match, month: Match, day: Match, week_day: Match };

const Date = struct { year: i64, month: i64, day: i64 };

// https://howardhinnant.github.io/date_algorithms.html#civil_from_days
fn dateFromTimestamp(timestamp: i64) Date {
    const seconds_in_day = 24 * 60 * 60;
    var z = @divFloor(timestamp, seconds_in_day);
    z += 719468;
    const era = @divFloor(if (z >= 0) z else z - 146096, 146097);
    const doe = (z - era * 146097);
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36524) - @divFloor(doe, 146096), 365);
    const y = (yoe) + era * 400;
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const d = doy - @divFloor(153 * mp + 2, 5) + 1;
    const m = if (mp < 10) mp + 3 else mp - 9;
    return .{ .year = if (m <= 2) y else y + 1, .month = m, .day = d };
}

// https://howardhinnant.github.io/date_algorithms.html#days_from_civil
fn dateToTimestamp(date: Date) i64 {
    var y = date.year;
    const m = date.month;
    const d = date.day;
    if (m > 2) {
        y -= 1;
    }
    const era = @divFloor(if (y >= 0) y else y - 399, 400);
    const yoe = y - era * 400;
    const doy = @divFloor((153 * (if (m > 2) m - 3 else m + 9) + 2), 5) + d - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    const seconds_in_day = 24 * 60 * 60;
    return seconds_in_day * (era * 146097 + doe - 719468);
}

test "date" {
    const std = @import("std");
    const timestamp = std.time.timestamp();
    const date = dateFromTimestamp(timestamp);
    std.debug.print("{any}\n", .{date});
    std.debug.print("{any}\n", .{timestamp});
    std.debug.print("{any}\n", .{dateToTimestamp(date)});
    std.debug.print("{any}\n", .{dateFromTimestamp(dateToTimestamp(date))});
}
