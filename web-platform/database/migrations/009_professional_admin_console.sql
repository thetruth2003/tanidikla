alter table reports add column if not exists priority text not null default 'normal';
alter table reports add column if not exists admin_note text not null default '';
alter table reports add column if not exists assigned_to uuid references users(id) on delete set null;
alter table reports add column if not exists updated_at timestamptz not null default now();

do $migration$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'reports_priority_check'
  ) then
    alter table reports
      add constraint reports_priority_check
      check (priority in ('low', 'normal', 'high', 'critical'));
  end if;
end
$migration$;

create index if not exists reports_admin_queue_idx
  on reports (status, priority, created_at desc);
create index if not exists reports_reason_status_idx
  on reports (reason, status, created_at desc);

alter table categories add column if not exists updated_at timestamptz not null default now();

insert into permissions (code, description) values
  ('categories.create', 'Yeni kategori ve alt kategori oluşturma'),
  ('categories.delete', 'Kullanılmayan kategoriyi silme veya arşivleme')
on conflict (code) do update set description = excluded.description;

insert into role_permissions (role, permission_code)
select 'super_admin', code from permissions
where code in ('categories.create', 'categories.delete')
on conflict do nothing;

insert into role_permissions (role, permission_code)
select 'admin', code from permissions
where code in ('categories.create', 'categories.delete')
on conflict do nothing;
