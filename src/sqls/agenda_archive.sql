INSERT INTO agenda_archive (
        scheduler_id,
        scheduler_archive_id,
        description,
        tags_csv,
        monetary_value,
        due_at,
        archived_at
    )
    SELECT scheduler_id,
           scheduler_archive_id,
           description,
           tags_csv,
           monetary_value,
           due_at,
           ?            -- 1 archived_at
        FROM agenda
        WHERE id = ?    -- 2 agenda_id
    ;

