create table if not exists media_objects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references users(id) on delete cascade,
  storage_driver text not null check (storage_driver in ('local', 's3')),
  storage_key text not null unique,
  purpose text not null check (purpose in ('listing_image', 'avatar', 'message_attachment')),
  visibility text not null default 'public' check (visibility in ('public', 'private')),
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  byte_size integer not null check (byte_size > 0),
  width integer not null check (width > 0),
  height integer not null check (height > 0),
  sha256 char(64) not null,
  created_at timestamptz not null default now()
);
create index if not exists media_objects_owner_idx on media_objects (owner_id, created_at desc);

alter table listing_images
  add column if not exists media_id uuid references media_objects(id) on delete cascade;
create unique index if not exists listing_images_media_uidx
  on listing_images (media_id) where media_id is not null;

alter table profiles
  add column if not exists avatar_media_id uuid references media_objects(id) on delete set null;
