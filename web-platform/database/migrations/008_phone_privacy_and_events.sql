alter table profiles
  add column if not exists phone_e164 varchar(16),
  add column if not exists phone_visible boolean not null default false;

alter table profiles drop constraint if exists profiles_phone_e164_check;
alter table profiles add constraint profiles_phone_e164_check
  check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$');

create table if not exists analytics_events (
  id bigint generated always as identity primary key,
  user_id uuid references users(id) on delete set null,
  event_type text not null check (event_type in ('listing_view', 'favorite_add', 'message_start', 'share', 'phone_reveal', 'search')),
  subject_type text not null default '',
  subject_id text not null default '',
  request_id text not null default '',
  ip_address inet,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists analytics_events_type_created_idx on analytics_events (event_type, created_at desc);
create index if not exists analytics_events_user_created_idx on analytics_events (user_id, created_at desc) where user_id is not null;
