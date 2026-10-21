create table if not exists service_engagements (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references users(id) on delete restrict,
  provider_id uuid not null references users(id) on delete restrict,
  listing_id uuid references listings(id) on delete set null,
  listing_item_id uuid references listing_items(id) on delete set null,
  conversation_id uuid references conversations(id) on delete set null,
  listing_headline_snapshot text not null,
  service_name_snapshot text not null,
  service_description_snapshot text not null default '',
  category_id_snapshot text,
  quoted_price_amount numeric(12,2),
  agreed_price_amount numeric(12,2),
  currency_snapshot char(3) not null default 'TRY',
  pricing_unit_snapshot text not null,
  status text not null default 'requested',
  version integer not null default 1,
  cancellation_reason text not null default '',
  canceled_by uuid references users(id) on delete set null,
  dispute_reason text not null default '',
  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  accepted_at timestamptz,
  started_at timestamptz,
  provider_completed_at timestamptz,
  requester_confirmed_at timestamptz,
  completed_at timestamptz,
  canceled_at timestamptz,
  updated_at timestamptz not null default now(),
  check (requester_id <> provider_id),
  check (quoted_price_amount is null or quoted_price_amount >= 0),
  check (agreed_price_amount is null or agreed_price_amount >= 0),
  check (currency_snapshot ~ '^[A-Z]{3}$'),
  check (pricing_unit_snapshot in ('fixed','hourly','daily','per_session','starting_at','negotiable','free')),
  check (status in ('requested','accepted','rejected','in_progress','provider_completed','completed','canceled','disputed')),
  check (char_length(cancellation_reason) <= 1000),
  check (char_length(dispute_reason) <= 2000)
);
create index if not exists service_engagements_requester_idx on service_engagements (requester_id, updated_at desc);
create index if not exists service_engagements_provider_idx on service_engagements (provider_id, updated_at desc);
create index if not exists service_engagements_status_idx on service_engagements (status, updated_at desc);
create index if not exists service_engagements_listing_idx on service_engagements (listing_id, listing_item_id);

create table if not exists service_engagement_events (
  id bigint generated always as identity primary key,
  engagement_id uuid not null references service_engagements(id) on delete cascade,
  actor_id uuid references users(id) on delete set null,
  from_status text,
  to_status text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists service_engagement_events_engagement_idx
  on service_engagement_events (engagement_id, id);

alter table conversations
  add column if not exists listing_item_id uuid references listing_items(id) on delete set null,
  add column if not exists engagement_id uuid references service_engagements(id) on delete set null;
create index if not exists conversations_listing_item_idx on conversations (listing_item_id);
create unique index if not exists conversations_engagement_uidx on conversations (engagement_id) where engagement_id is not null;

alter table reviews
  add column if not exists engagement_id uuid references service_engagements(id) on delete set null,
  add column if not exists submitted_at timestamptz not null default now(),
  add column if not exists published_at timestamptz,
  add column if not exists publish_after timestamptz not null default (now() + interval '14 days'),
  add column if not exists moderation_note text not null default '';

alter table reviews alter column comment drop not null;
alter table reviews drop constraint if exists reviews_comment_check;
alter table reviews add constraint reviews_comment_check
  check (comment is null or char_length(comment) between 1 and 1000);
do $$
declare constraint_name text;
begin
  for constraint_name in
    select conname from pg_constraint
    where conrelid = 'reviews'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%status%'
  loop execute format('alter table reviews drop constraint %I', constraint_name); end loop;
end $$;
alter table reviews add constraint reviews_status_check
  check (status in ('pending','published','hidden','removed'));
create unique index if not exists reviews_engagement_author_uidx
  on reviews (engagement_id, author_id) where engagement_id is not null and status <> 'removed';
create index if not exists reviews_pending_publish_idx
  on reviews (publish_after) where status = 'pending';

insert into permissions (code, description) values
  ('engagements.view', 'İş kayıtlarını görüntüleme'),
  ('engagements.moderate', 'İş ve anlaşmazlık kayıtlarını yönetme'),
  ('reviews.moderate', 'Doğrulanmış değerlendirmeleri yönetme')
on conflict (code) do update set description = excluded.description;
insert into role_permissions (role, permission_code)
select role, permission_code
from (values ('moderator'),('admin'),('super_admin')) roles(role)
cross join (values ('engagements.view'),('engagements.moderate'),('reviews.moderate')) permissions(permission_code)
on conflict do nothing;

-- New event types share the existing notifications/outbox delivery pipeline.
do $$
declare constraint_name text;
begin
  for constraint_name in
    select conname from pg_constraint
    where conrelid = 'notifications'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%type%'
  loop execute format('alter table notifications drop constraint %I', constraint_name); end loop;
end $$;
alter table notifications add constraint notifications_type_check check (
  type in ('message','review','listing','system','service_request','engagement','dispute','moderation')
);

