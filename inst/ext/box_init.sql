CREATE TABLE IF NOT EXISTS BOX (
  id TEXT PRIMARY KEY,
  object BLOB,
  info TEXT,
  tags TEXT,
  class TEXT,
  changed TIMESTAMP
);
