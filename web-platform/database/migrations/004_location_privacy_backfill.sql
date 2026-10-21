-- Older exact-address rows stored the private coordinate in the public columns.
-- Move those map pins 350–650 metres in a random direction once. The original
-- coordinate remains available only in private_listing_addresses.
with offsets as (
  select l.id,
         a.exact_latitude,
         a.exact_longitude,
         random() * 2 * pi() as bearing,
         350 + random() * 300 as distance_meters
  from listings l
  join private_listing_addresses a on a.listing_id = l.id
  where l.location_precision = 'exact'
    and a.exact_latitude is not null
    and a.exact_longitude is not null
)
update listings l
set public_latitude = greatest(-90.0, least(90.0,
      o.exact_latitude + cos(o.bearing) * o.distance_meters / 111320.0)),
    public_longitude = greatest(-180.0, least(180.0,
      o.exact_longitude + sin(o.bearing) * o.distance_meters /
        (111320.0 * greatest(0.1, cos(radians(o.exact_latitude)))))),
    updated_at = now()
from offsets o
where l.id = o.id;
