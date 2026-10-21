alter table user_sessions
  add column if not exists session_type text not null default 'web'
  check (session_type in ('web', 'legacy'));

create table api_token_families (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  device_name text not null default '',
  ip_address inet,
  user_agent text not null default '',
  last_used_at timestamptz not null default now(),
  revoked_at timestamptz,
  compromised_at timestamptz,
  created_at timestamptz not null default now()
);
create index api_token_families_user_idx
  on api_token_families (user_id, created_at desc);

create table api_access_tokens (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references api_token_families(id) on delete cascade,
  token_hash char(64) not null unique,
  expires_at timestamptz not null,
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index api_access_tokens_family_idx
  on api_access_tokens (family_id, expires_at desc);

create table api_refresh_tokens (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references api_token_families(id) on delete cascade,
  token_hash char(64) not null unique,
  expires_at timestamptz not null,
  rotated_at timestamptz,
  replaced_by_id uuid references api_refresh_tokens(id) on delete set null,
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index api_refresh_tokens_family_idx
  on api_refresh_tokens (family_id, expires_at desc);

create table email_queue (
  id bigint generated always as identity primary key,
  recipient text not null,
  subject text not null,
  html_body text not null,
  text_body text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  processing_started_at timestamptz,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);
create index email_queue_pending_idx
  on email_queue (next_attempt_at, id)
  where status in ('pending', 'failed');
