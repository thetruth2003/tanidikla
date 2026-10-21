create table notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references users(id) on delete cascade,
  type text not null check (type in ('message', 'review', 'listing', 'system')),
  title text not null check (char_length(title) between 1 and 160),
  body text not null default '' check (char_length(body) <= 500),
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_unread_idx
  on notifications (user_id, created_at desc) where read_at is null;
create index notifications_user_created_idx on notifications (user_id, created_at desc);

create table realtime_outbox (
  id bigint generated always as identity primary key,
  channel text not null,
  event_type text not null,
  payload jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'published', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  processing_started_at timestamptz,
  published_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);
create index realtime_outbox_pending_idx on realtime_outbox (next_attempt_at, id)
  where status in ('pending', 'failed');

create table sms_queue (
  id bigint generated always as identity primary key,
  recipient text not null,
  message text not null check (char_length(message) between 1 and 1000),
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  processing_started_at timestamptz,
  provider_reference text,
  sent_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);
create index sms_queue_pending_idx on sms_queue (next_attempt_at, id)
  where status in ('pending', 'failed');

create table device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  token_hash char(64) not null unique,
  encrypted_token text not null,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index device_push_tokens_user_idx on device_push_tokens (user_id, last_seen_at desc);
