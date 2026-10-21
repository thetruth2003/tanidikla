alter table listings
  add column if not exists submission_fingerprint char(64),
  add column if not exists moderation_score smallint not null default 0,
  add column if not exists moderation_flags jsonb not null default '[]'::jsonb,
  add column if not exists submitted_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid references users(id) on delete set null,
  add column if not exists approval_notified_at timestamptz;

alter table listings alter column status set default 'pending';

do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select conname
    from pg_constraint
    where conrelid = 'listings'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) like '%status%'
  loop
    execute format('alter table listings drop constraint %I', constraint_name);
  end loop;

  alter table listings add constraint listings_status_check
    check (status in ('draft', 'pending', 'active', 'paused', 'completed', 'expired', 'rejected', 'removed'));
end
$$;

create index if not exists listings_submission_fingerprint_idx
  on listings (owner_id, submission_fingerprint, created_at desc)
  where submission_fingerprint is not null and status <> 'removed';

create index if not exists listings_pending_moderation_idx
  on listings (moderation_score desc, submitted_at asc)
  where status = 'pending';

create table if not exists listing_submission_keys (
  user_id uuid not null references users(id) on delete cascade,
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 160),
  listing_id uuid references listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  primary key (user_id, idempotency_key)
);

create index if not exists listing_submission_keys_expiry_idx
  on listing_submission_keys (expires_at);
