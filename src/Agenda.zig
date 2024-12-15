const Agenda = @This();

const zsqlite = @import("zsqlite");

id: i64,
scheduler_id: i64,
scheduler_archive_id: i64,
description: []const u8,
tags_csv: []const u8,
monetary_value: i64,
due_at: i64,

pub fn init(row: zsqlite.Row) Agenda {
    const id = row.column(0, i64);
    const scheduler_id = row.column(1, i64);
    const scheduler_archive_id = row.column(2, i64);
    const description = row.columnTextPtr(3);
    const tags_csv = row.columnTextPtr(4);
    const monetary_value = row.column(5, i64);
    const due_at = row.column(6, i64);
    return Agenda{
        .id = id,
        .scheduler_id = scheduler_id,
        .scheduler_archive_id = scheduler_archive_id,
        .description = description,
        .tags_csv = tags_csv,
        .monetary_value = monetary_value,
        .due_at = due_at,
    };
}
