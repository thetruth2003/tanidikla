alter table private_listing_addresses
  add column if not exists apartment_number text not null default '';

