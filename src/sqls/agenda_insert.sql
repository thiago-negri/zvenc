INSERT INTO agenda (
    scheduler_id,
    description,
    tags_csv,
    monetary_value,
    due_at
) VALUES (
    ?, -- 1 scheduler_id
    ?, -- 2 description
    ?, -- 3 tags_csv
    ?, -- 4 monetary_value
    ?  -- 5 due_at
);

