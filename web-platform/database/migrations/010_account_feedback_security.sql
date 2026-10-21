alter table users
  add column if not exists pending_email text;

alter table profiles
  add column if not exists phone_verified_at timestamptz,
  add column if not exists message_email_notifications boolean not null default false;

create unique index if not exists profiles_verified_phone_uidx
  on profiles (phone_e164)
  where phone_e164 is not null and phone_verified_at is not null;

create table if not exists email_change_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  new_email text not null,
  token_hash char(64) not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists email_change_tokens_user_idx
  on email_change_tokens (user_id, created_at desc);

create table if not exists phone_verification_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  phone_e164 varchar(16) not null,
  code_hash char(64) not null,
  attempts integer not null default 0 check (attempts between 0 and 10),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists phone_verification_codes_user_idx
  on phone_verification_codes (user_id, created_at desc);

alter table listings
  add column if not exists service_radius_km integer not null default 25;
alter table listings drop constraint if exists listings_service_radius_km_check;
alter table listings add constraint listings_service_radius_km_check
  check (service_radius_km between 1 and 100);

create table if not exists message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id bigint not null references messages(id) on delete cascade,
  media_id uuid not null unique references media_objects(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists message_attachments_message_idx
  on message_attachments (message_id, created_at);

