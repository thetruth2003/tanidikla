alter table listings
  alter column service_radius_km drop not null,
  alter column service_radius_km drop default,
  add column if not exists preferred_provider_kind text,
  add column if not exists preferred_provider_gender text;

alter table listings drop constraint if exists listings_service_radius_km_check;
alter table listings add constraint listings_service_radius_km_check
  check (service_radius_km is null or service_radius_km between 1 and 100);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'listings_preferred_provider_kind_check'
      and conrelid = 'listings'::regclass
  ) then
    alter table listings add constraint listings_preferred_provider_kind_check
      check (preferred_provider_kind is null or preferred_provider_kind in ('person', 'business'));
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'listings_preferred_provider_gender_check'
      and conrelid = 'listings'::regclass
  ) then
    alter table listings add constraint listings_preferred_provider_gender_check
      check (preferred_provider_gender is null or preferred_provider_gender in ('female', 'male'));
  end if;
end
$$;
