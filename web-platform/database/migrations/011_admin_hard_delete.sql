insert into permissions (code, description) values
  ('users.delete', 'Kullanıcı hesabını kalıcı olarak silme'),
  ('listings.delete', 'İlanı kalıcı olarak silme')
on conflict (code) do update set description = excluded.description;

insert into role_permissions (role, permission_code) values
  ('super_admin', 'users.delete'),
  ('super_admin', 'listings.delete')
on conflict do nothing;
