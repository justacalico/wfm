CREATE TABLE announcements(
  id TEXT PRIMARY KEY,
  author_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  comments_enabled INTEGER NOT NULL DEFAULT 1,
  reactions_enabled INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  edited_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX announcements_created ON announcements(created_at);
CREATE TABLE announcement_reactions(
  announcement_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  emoji TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(announcement_id,user_id,emoji)
);
CREATE TABLE announcement_comments(
  id TEXT PRIMARY KEY,
  announcement_id TEXT NOT NULL,
  author_id TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  edited_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX announcement_comments_ann ON announcement_comments(announcement_id);
