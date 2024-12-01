const std = @import("std");
pub const data = @import("./data.zig");
pub const date = @import("./date.zig");
pub const rule = @import("./rule.zig");

test {
    std.testing.refAllDecls(@This());
}
