create extension if not exists pg_trgm;
create extension if not exists unaccent;

create index if not exists listing_items_search_trgm_idx
  on listing_items using gin ((lower(title || ' ' || description)) gin_trgm_ops);
create index if not exists profiles_display_name_trgm_idx
  on profiles using gin (lower(display_name) gin_trgm_ops);
create index if not exists favorites_listing_idx
  on favorites (listing_id, created_at desc);

alter table reviews
  add column if not exists status text not null default 'published',
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'reviews_status_check' and conrelid = 'reviews'::regclass
  ) then
    alter table reviews add constraint reviews_status_check
      check (status in ('published', 'hidden', 'removed'));
  end if;
end
$$;

create table if not exists user_blocks (
  blocker_id uuid not null references users(id) on delete cascade,
  blocked_user_id uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_user_id),
  check (blocker_id <> blocked_user_id)
);
create index if not exists user_blocks_blocked_idx
  on user_blocks (blocked_user_id, created_at desc);

create index if not exists reports_status_created_idx
  on reports (status, created_at desc);
create unique index if not exists reports_active_listing_uidx
  on reports (reporter_id, listing_id)
  where listing_id is not null and status in ('open', 'reviewing');
create unique index if not exists reports_active_user_uidx
  on reports (reporter_id, reported_user_id)
  where reported_user_id is not null and status in ('open', 'reviewing');

-- PostGIS production images expose the extension to PostgreSQL. Local developer
-- machines without its native Windows binaries keep working with the indexed
-- latitude/longitude fallback; deploying PostGIS automatically upgrades the
-- same schema to geography(Point, 4326).
do $migration$
begin
  if exists (select 1 from pg_available_extensions where name = 'postgis') then
    create extension if not exists postgis;
    execute 'alter table listings add column if not exists public_location geography(Point, 4326)';
    execute 'update listings
             set public_location = ST_SetSRID(ST_MakePoint(public_longitude, public_latitude), 4326)::geography
             where public_location is null';
    execute 'create index if not exists listings_public_location_gix
             on listings using gist (public_location)';

    execute $function$
      create or replace function sync_listing_public_location()
      returns trigger
      language plpgsql
      as $body$
      begin
        new.public_location := ST_SetSRID(ST_MakePoint(new.public_longitude, new.public_latitude), 4326)::geography;
        return new;
      end
      $body$
    $function$;

    if not exists (select 1 from pg_trigger where tgname = 'listings_public_location_sync') then
      execute 'create trigger listings_public_location_sync
               before insert or update of public_latitude, public_longitude on listings
               for each row execute function sync_listing_public_location()';
    end if;
  end if;
end
$migration$;
