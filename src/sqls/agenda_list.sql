SELECT /* 0: */ id,
       /* 1: */ scheduler_id,
       /* 2: */ scheduler_archive_id,
       /* 3: */ description,
       /* 4: */ tags_csv,
       /* 5: */ monetary_value,
       /* 6: */ due_at
    FROM agenda
    -- DESC so the 'due' items show at the very bottom
    -- when opening up a new shell session.
    -- So even on small height terminals you'll see the
    -- due items.
    ORDER BY due_at DESC, id DESC;
