SELECT /* 0: */ id,
       /* 1: */ scheduler_id,
       /* 2: */ scheduler_archive_id,
       /* 3: */ description,
       /* 4: */ tags_csv,
       /* 5: */ monetary_value,
       /* 6: */ due_at
    FROM agenda
    ORDER BY due_at ASC;
