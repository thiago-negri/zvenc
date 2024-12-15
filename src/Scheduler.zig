const Scheduler = @This();

const Rule = @import("Rule.zig");
const std = @import("std");
const zsqlite = @import("zsqlite");

id: i64,
rule: []const u8,
rule_parsed: Rule,
description: []const u8,
tags_csv: []const u8,
monetary_value: i64,

pub fn init(alloc: std.mem.Allocator, row: zsqlite.Row) (std.fmt.ParseIntError || std.mem.Allocator.Error)!Scheduler {
    const id = row.column(0, i64);
    const rule = try row.columnText(1, alloc);
    const description = try row.columnText(2, alloc);
    const tags_csv = try row.columnText(3, alloc);
    const monetary_value = row.column(4, i64);
    const rule_parsed = try Rule.parse(rule, alloc);
    return Scheduler{
        .id = id,
        .rule = rule,
        .rule_parsed = rule_parsed,
        .description = description,
        .tags_csv = tags_csv,
        .monetary_value = monetary_value,
    };
}

pub fn deinit(self: Scheduler, alloc: std.mem.Allocator) void {
    alloc.free(self.rule);
    alloc.free(self.description);
    alloc.free(self.tags_csv);
    self.rule_parsed.deinit(alloc);
}
