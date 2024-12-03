const std = @import("std");
pub const data = @import("./data.zig");
pub const Date = @import("./Date.zig");
pub const rule = @import("./rule.zig");

test {
    std.testing.refAllDecls(@This());
}
