-- Only active rules
CREATE TABLE scheduler (
    id INTEGER PRIMARY KEY,
    rule TEXT,
    description TEXT,
    tags_csv TEXT,
    monetary_value INT,
    created_at INT
);

-- Deleted rules
CREATE TABLE scheduler_archive (
    id INTEGER PRIMARY KEY,
    rule TEXT,
    description TEXT,
    tags_csv TEXT,
    monetary_value INT,
    created_at INT,
    archived_at INT
);

-- To do entries
CREATE TABLE agenda (
    id INTEGER PRIMARY KEY,
    scheduler_id INT,
    scheduler_archive_id INT,
    description TEXT,
    tags_csv TEXT,
    monetary_value INT,
    due_at INT,
    FOREIGN KEY (scheduler_id) REFERENCES scheduler (id),
    FOREIGN KEY (scheduler_archive_id) REFERENCES scheduler_archive (id)
);

-- Completed entries
CREATE TABLE agenda_archive (
    id INTEGER PRIMARY KEY,
    scheduler_id INT,
    scheduler_archive_id INT,
    description TEXT,
    tags_csv TEXT,
    monetary_value INT,
    due_at INT,
    archived_at INT,
    FOREIGN KEY (scheduler_id) REFERENCES scheduler (id),
    FOREIGN KEY (scheduler_archive_id) REFERENCES scheduler_archive (id)
);

-- Controls when the scheduler ran
CREATE TABLE scheduler_control (
    id INTEGER PRIMARY KEY,
    last_run_at_timestamp INT
);

