alter table reports
  add column if not exists listing_item_id uuid references listing_items(id) on delete set null,
  add column if not exists message_id bigint references messages(id) on delete set null,
  add column if not exists engagement_id uuid references service_engagements(id) on delete set null,
  add column if not exists review_id uuid references reviews(id) on delete set null;

do $$
declare constraint_name text;
begin
  for constraint_name in
    select conname from pg_constraint
    where conrelid = 'reports'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%listing_id%'
      and pg_get_constraintdef(oid) like '%reported_user_id%'
  loop execute format('alter table reports drop constraint %I', constraint_name); end loop;
end $$;
alter table reports add constraint reports_has_target_check check (
  num_nonnulls(listing_id, reported_user_id, listing_item_id, message_id, engagement_id, review_id) = 1
);
create unique index if not exists reports_active_item_uidx on reports (reporter_id, listing_item_id)
  where listing_item_id is not null and status in ('open','reviewing');
create unique index if not exists reports_active_message_uidx on reports (reporter_id, message_id)
  where message_id is not null and status in ('open','reviewing');
create unique index if not exists reports_active_engagement_uidx on reports (reporter_id, engagement_id)
  where engagement_id is not null and status in ('open','reviewing');
create unique index if not exists reports_active_review_uidx on reports (reporter_id, review_id)
  where review_id is not null and status in ('open','reviewing');

create table if not exists risk_signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete set null,
  related_user_id uuid references users(id) on delete set null,
  engagement_id uuid references service_engagements(id) on delete set null,
  review_id uuid references reviews(id) on delete set null,
  signal_type text not null,
  score smallint not null check (score between 1 and 100),
  evidence jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open','reviewing','dismissed','confirmed')),
  reviewed_by uuid references users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists risk_signals_queue_idx on risk_signals (status, score desc, created_at);
create index if not exists risk_signals_user_idx on risk_signals (user_id, created_at desc);

create table if not exists beta_invites (
  id uuid primary key default gen_random_uuid(),
  code_hash char(64) not null unique,
  label text not null default '',
  max_uses integer not null default 1 check (max_uses > 0),
  use_count integer not null default 0 check (use_count >= 0),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists beta_members (
  user_id uuid primary key references users(id) on delete cascade,
  invite_id uuid references beta_invites(id) on delete set null,
  enabled boolean not null default true,
  joined_at timestamptz not null default now()
);
create table if not exists beta_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  kind text not null check (kind in ('bug','suggestion','usability','other')),
  title text not null check (char_length(title) between 3 and 160),
  details text not null check (char_length(details) between 10 and 4000),
  client_context jsonb not null default '{}'::jsonb,
  status text not null default 'new' check (status in ('new','reviewing','planned','resolved','closed')),
  admin_note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists beta_feedback_queue_idx on beta_feedback (status, created_at desc);

create table if not exists push_delivery_queue (
  id bigint generated always as identity primary key,
  notification_id bigint references notifications(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  platform text not null check (platform in ('android','ios','web')),
  payload jsonb not null,
  status text not null default 'pending' check (status in ('pending','processing','sent','failed','unconfigured')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists push_delivery_queue_pending_idx on push_delivery_queue (next_attempt_at, id)
  where status in ('pending','failed');

insert into permissions (code, description) values
  ('risk.view', 'Şüpheli hareketleri görüntüleme'),
  ('risk.moderate', 'Şüpheli hareketleri inceleme'),
  ('beta.manage', 'Kapalı beta kullanıcı ve geri bildirimlerini yönetme')
on conflict (code) do update set description = excluded.description;
insert into role_permissions (role, permission_code)
select role, permission_code
from (values ('admin'),('super_admin')) roles(role)
cross join (values ('risk.view'),('risk.moderate'),('beta.manage')) permissions(permission_code)
on conflict do nothing;
insert into role_permissions (role, permission_code) values ('moderator','risk.view') on conflict do nothing;

