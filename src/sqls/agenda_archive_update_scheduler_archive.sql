UPDATE agenda_archive
    SET scheduler_archive_id = ?, -- 1 scheduler_archive_id
        scheduler_id = NULL
    WHERE scheduler_id = ?;       -- 2 scheduler_id


