INSERT INTO scheduler_archive (
        rule,
        description,
        tags_csv,
        monetary_value,
        created_at,
        archived_at
    )
    SELECT rule,
           description,
           tags_csv,
           monetary_value,
           created_at,
           ?            -- 1 archived_at
        FROM scheduler
        WHERE id = ?    -- 2 scheduler_id
    RETURNING id;
