-- A listing remains one map entity while exposing one or more independently
-- priced service items. Existing rows already represent the first service item.
alter table listings
  add column if not exists headline text,
  add column if not exists summary text not null default '';

update listings l
set headline = (
  select li.title from listing_items li
  where li.listing_id = l.id order by li.page_index limit 1
)
where l.headline is null;

-- Defensive fallback for historic/incomplete records without an item.
update listings set headline = 'İlan' where headline is null;

alter table listings alter column headline set not null;
alter table listings drop constraint if exists listings_headline_length_check;
alter table listings add constraint listings_headline_length_check
  check (char_length(headline) between 3 and 140);
alter table listings drop constraint if exists listings_summary_length_check;
alter table listings add constraint listings_summary_length_check
  check (char_length(summary) <= 1000);

alter table listing_items
  add column if not exists currency char(3) not null default 'TRY',
  add column if not exists estimated_duration_minutes integer,
  add column if not exists is_active boolean not null default true,
  add column if not exists deleted_at timestamptz;

alter table listing_items drop constraint if exists listing_items_currency_check;
alter table listing_items add constraint listing_items_currency_check
  check (currency ~ '^[A-Z]{3}$');
alter table listing_items drop constraint if exists listing_items_duration_check;
alter table listing_items add constraint listing_items_duration_check
  check (estimated_duration_minutes is null or estimated_duration_minutes between 5 and 525600);

do $$
declare constraint_name text;
begin
  for constraint_name in
    select conname from pg_constraint
    where conrelid = 'listing_items'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%pricing_unit%'
  loop execute format('alter table listing_items drop constraint %I', constraint_name); end loop;
end $$;
alter table listing_items add constraint listing_items_pricing_unit_check
  check (pricing_unit in ('fixed','hourly','daily','per_session','starting_at','negotiable','free'));
alter table listing_items drop constraint if exists listing_items_price_semantics_check;
alter table listing_items add constraint listing_items_price_semantics_check check (
  (pricing_unit in ('negotiable','free') and price_amount is null)
  or (pricing_unit not in ('negotiable','free') and price_amount is not null and price_amount >= 0)
);

create index if not exists listing_items_active_listing_idx
  on listing_items (listing_id, page_index) where is_active and deleted_at is null;
create index if not exists listing_items_active_category_idx
  on listing_items (category_id, listing_id) where is_active and deleted_at is null;

insert into permissions (code, description) values
  ('listing_items.manage', 'İlan hizmet kalemlerini yönetme')
on conflict (code) do update set description = excluded.description;
insert into role_permissions (role, permission_code)
select role, 'listing_items.manage' from (values ('admin'),('super_admin')) roles(role)
on conflict do nothing;
