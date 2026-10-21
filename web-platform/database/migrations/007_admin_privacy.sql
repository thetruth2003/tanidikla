alter table users add column if not exists suspended_reason text not null default '';
alter table users add column if not exists suspended_at timestamptz;
alter table users add column if not exists anonymized_at timestamptz;
alter table listings add column if not exists moderation_note text not null default '';

create table admin_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash char(64) not null unique,
  csrf_hash char(64) not null,
  ip_address inet,
  user_agent text not null default '',
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index admin_sessions_user_idx on admin_sessions (user_id, expires_at desc);

create table permissions (
  code text primary key,
  description text not null
);
create table role_permissions (
  role text not null check (role in ('moderator', 'admin', 'super_admin')),
  permission_code text not null references permissions(code) on delete cascade,
  primary key (role, permission_code)
);

insert into permissions (code, description) values
  ('dashboard.view', 'Yönetim özetini görüntüleme'),
  ('users.view', 'Kullanıcıları görüntüleme'),
  ('users.suspend', 'Kullanıcı askıya alma ve açma'),
  ('listings.view', 'İlanları görüntüleme'),
  ('listings.moderate', 'İlan durumunu yönetme'),
  ('reports.view', 'Şikâyetleri görüntüleme'),
  ('reports.resolve', 'Şikâyet sonuçlandırma'),
  ('categories.manage', 'Kategori yönetme'),
  ('banners.manage', 'Banner yönetme'),
  ('audit.view', 'Yönetim denetim kayıtlarını görüntüleme'),
  ('privacy.manage', 'KVKK metin ve taleplerini yönetme')
on conflict (code) do update set description = excluded.description;

insert into role_permissions (role, permission_code)
select 'super_admin', code from permissions on conflict do nothing;
insert into role_permissions (role, permission_code)
select 'admin', code from permissions where code <> 'audit.view' on conflict do nothing;
insert into role_permissions (role, permission_code) values
  ('moderator', 'dashboard.view'), ('moderator', 'users.view'),
  ('moderator', 'listings.view'), ('moderator', 'listings.moderate'),
  ('moderator', 'reports.view'), ('moderator', 'reports.resolve')
on conflict do nothing;

create table policy_documents (
  id uuid primary key default gen_random_uuid(),
  document_type text not null check (document_type in ('kvkk_notice', 'privacy_policy', 'terms', 'cookie_policy')),
  version text not null,
  title text not null,
  content text not null,
  status text not null default 'draft' check (status in ('draft', 'published', 'retired')),
  published_at timestamptz,
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (document_type, version)
);
create unique index policy_documents_current_uidx on policy_documents (document_type) where status = 'published';

create table user_consents (
  id bigint generated always as identity primary key,
  user_id uuid not null references users(id) on delete cascade,
  policy_document_id uuid not null references policy_documents(id) on delete restrict,
  action text not null check (action in ('accepted', 'withdrawn')),
  ip_address inet,
  user_agent text not null default '',
  created_at timestamptz not null default now()
);
create index user_consents_user_idx on user_consents (user_id, created_at desc);

create table privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete restrict,
  request_type text not null check (request_type in ('export', 'deletion', 'correction', 'objection')),
  details text not null default '',
  status text not null default 'pending' check (status in ('pending', 'processing', 'completed', 'rejected')),
  result_path text,
  reviewed_by uuid references users(id) on delete set null,
  reviewed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index privacy_requests_status_idx on privacy_requests (status, created_at);
create unique index privacy_requests_open_unique on privacy_requests (user_id, request_type)
  where status in ('pending', 'processing');
