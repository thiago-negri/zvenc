SELECT 1
    FROM agenda
    WHERE scheduler_id = ? -- 1: scheduler_id
      AND due_at = ?       -- 2: due_at
    LIMIT 1
;
