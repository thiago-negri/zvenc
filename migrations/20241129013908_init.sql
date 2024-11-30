-- Only active rules
CREATE TABLE scheduler (
	id INT PRIMARY KEY,
	rule TEXT,
	description TEXT,
	tags_csv TEXT,
	value INT,
	created_at INT
);

-- Deleted rules
CREATE TABLE scheduler_archive (
	id INT PRIMARY KEY,
	rule TEXT,
	description TEXT,
	tags_csv TEXT,
	value INT,
	created_at INT,
	archived_at INT
);

-- To do entries
CREATE TABLE agenda (
	id INT PRIMARY KEY,
	scheduler_id INT,
	rule TEXT,
	description TEXT,
	tags_csv TEXT,
	value INT
);

-- Completed entries
CREATE TABLE agenda_archive (
	id INT PRIMARY KEY,
	scheduler_id INT,
	rule TEXT,
	description TEXT,
	tags_csv TEXT,
	value INT,
	archived_at INT
);

-- Controls when the scheduler ran
CREATE TABLE scheduler_control (
	id INT PRIMARY KEY,
	last_run_at_timestamp INT
)
