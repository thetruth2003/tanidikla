create extension if not exists pgcrypto;

create table if not exists schema_migrations (
  version text primary key,
  applied_at timestamptz not null default now()
);

create table users (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  password_hash text not null,
  role text not null default 'user' check (role in ('user', 'moderator', 'admin', 'super_admin')),
  email_verified_at timestamptz,
  is_suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index users_email_lower_uidx on users (lower(email));

create table profiles (
  user_id uuid primary key references users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 80),
  avatar_path text,
  bio text not null default '' check (char_length(bio) <= 500),
  city text not null default 'Ankara',
  district text not null default '',
  is_provider boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash char(64) not null unique,
  csrf_hash char(64) not null,
  device_name text not null default '',
  ip_address inet,
  user_agent text not null default '',
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index user_sessions_user_idx on user_sessions (user_id, expires_at desc);

create table email_verification_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash char(64) not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table password_reset_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash char(64) not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table categories (
  id text primary key,
  label text not null,
  parent_id text references categories(id),
  sort_order integer not null,
  is_open_ended boolean not null default false,
  is_active boolean not null default true,
  is_selectable boolean not null default true,
  created_at timestamptz not null default now()
);
create index categories_active_parent_idx on categories (parent_id, sort_order) where is_active;

create table listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references users(id) on delete cascade,
  slug text not null unique,
  listing_type text not null check (listing_type in ('service_offer', 'service_request')),
  status text not null default 'active' check (status in ('draft', 'pending', 'active', 'paused', 'completed', 'expired', 'removed')),
  public_latitude double precision not null check (public_latitude between -90 and 90),
  public_longitude double precision not null check (public_longitude between -180 and 180),
  location_precision text not null check (location_precision in ('exact', 'neighborhood')),
  public_city text not null default 'Ankara',
  public_district text not null,
  public_neighborhood text not null,
  view_count bigint not null default 0,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index listings_location_idx on listings (public_latitude, public_longitude);
create index listings_active_idx on listings (status, listing_type, created_at desc);
create index listings_owner_idx on listings (owner_id, created_at desc);

create table listing_items (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  category_id text not null references categories(id),
  page_index integer not null check (page_index >= 0),
  title text not null check (char_length(title) between 3 and 120),
  description text not null check (char_length(description) between 10 and 2000),
  schedule_label text not null default '',
  price_amount numeric(12, 2) check (price_amount is null or price_amount >= 0),
  pricing_unit text not null check (pricing_unit in ('fixed', 'hourly', 'daily', 'negotiable')),
  price_includes_vat boolean not null default false,
  urgent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (listing_id, page_index)
);
create index listing_items_listing_idx on listing_items (listing_id, page_index);
create index listing_items_category_idx on listing_items (category_id, created_at desc);

create table private_listing_addresses (
  listing_id uuid primary key references listings(id) on delete cascade,
  owner_id uuid not null references users(id) on delete cascade,
  exact_latitude double precision check (exact_latitude is null or exact_latitude between -90 and 90),
  exact_longitude double precision check (exact_longitude is null or exact_longitude between -180 and 180),
  city text not null default '',
  district text not null default '',
  neighborhood text not null default '',
  street text not null default '',
  building_number text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  owner_id uuid not null references users(id) on delete cascade,
  storage_path text not null,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  width integer,
  height integer,
  byte_size integer not null check (byte_size > 0),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index listing_images_listing_idx on listing_images (listing_id, sort_order);

create table favorites (
  user_id uuid not null references users(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references listings(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table conversation_members (
  conversation_id uuid not null references conversations(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  last_read_message_id bigint,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index conversation_members_user_idx on conversation_members (user_id, joined_at desc);

create table messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz
);
create index messages_conversation_idx on messages (conversation_id, id desc);

alter table conversation_members
  add constraint conversation_members_last_read_fk
  foreign key (last_read_message_id) references messages(id) on delete set null;

create table reviews (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references listings(id) on delete set null,
  author_id uuid not null references users(id) on delete cascade,
  reviewed_user_id uuid not null references users(id) on delete cascade,
  rating numeric(2, 1) not null check (rating between 1 and 5),
  comment text not null check (char_length(comment) between 3 and 1000),
  created_at timestamptz not null default now(),
  check (author_id <> reviewed_user_id),
  unique (listing_id, author_id, reviewed_user_id)
);
create index reviews_user_idx on reviews (reviewed_user_id, created_at desc);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references users(id) on delete cascade,
  listing_id uuid references listings(id) on delete cascade,
  reported_user_id uuid references users(id) on delete cascade,
  reason text not null,
  details text not null default '',
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'rejected')),
  resolved_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (listing_id is not null or reported_user_id is not null)
);

create table banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  image_path text,
  target_url text,
  placement text not null default 'home',
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table admin_audit_logs (
  id bigint generated always as identity primary key,
  admin_user_id uuid not null references users(id) on delete restrict,
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  ip_address inet,
  created_at timestamptz not null default now()
);
create index admin_audit_logs_admin_idx on admin_audit_logs (admin_user_id, created_at desc);

create table rate_limits (
  bucket_key text primary key,
  attempts integer not null default 0,
  window_started_at timestamptz not null default now(),
  blocked_until timestamptz
);
