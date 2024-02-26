CREATE TABLE IF NOT EXISTS DEPOT (
  id TEXT PRIMARY KEY,
  object BLOB,
  info TEXT,
  tags TEXT,
  class TEXT,
  misc BLOB
);
