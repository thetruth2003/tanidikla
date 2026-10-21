alter table profiles
  add column if not exists profile_type text not null default 'person',
  add column if not exists business_name text,
  add column if not exists business_address text,
  add column if not exists business_services text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_profile_type_check' and conrelid = 'profiles'::regclass
  ) then
    alter table profiles add constraint profiles_profile_type_check
      check (profile_type in ('person', 'business'));
  end if;
end
$$;

alter table listing_items
  add column if not exists open_24_7 boolean not null default false;

create table if not exists saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 80),
  filters jsonb not null default '{}'::jsonb,
  notification_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists saved_searches_user_idx
  on saved_searches (user_id, updated_at desc);
