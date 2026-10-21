alter table beta_members
  add column if not exists last_seen_at timestamptz;

create index if not exists beta_members_activity_idx
  on beta_members (enabled, last_seen_at desc nulls last, joined_at desc);
