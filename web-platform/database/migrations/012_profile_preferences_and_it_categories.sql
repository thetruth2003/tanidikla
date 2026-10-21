alter table profiles
  add column if not exists gender text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'profiles_gender_check' and conrelid = 'profiles'::regclass
  ) then
    alter table profiles add constraint profiles_gender_check
      check (gender is null or gender in ('female', 'male', 'other', 'prefer_not_to_say'));
  end if;
end
$$;

create table if not exists profile_category_preferences (
  user_id uuid not null references users(id) on delete cascade,
  category_id text not null references categories(id) on delete cascade,
  preference_type text not null check (preference_type in ('receive', 'provide')),
  created_at timestamptz not null default now(),
  primary key (user_id, category_id, preference_type)
);

create index if not exists profile_category_preferences_match_idx
  on profile_category_preferences (preference_type, category_id, user_id);

insert into categories (id, label, sort_order, parent_id, is_open_ended, is_selectable) values
  ('computer_it', 'Bilgisayar ve IT', 700, null, false, false),
  ('computer_technical_support', 'Bilgisayar Teknik Destek', 710, 'computer_it', false, true),
  ('operating_system_installation', 'Format ve İşletim Sistemi Kurulumu', 720, 'computer_it', false, true),
  ('network_modem_setup', 'Modem ve Ağ Kurulumu', 730, 'computer_it', false, true),
  ('software_it_support', 'Yazılım ve IT Desteği', 740, 'computer_it', false, true),
  ('other_computer_it', 'Diğer Bilgisayar ve IT Hizmeti', 790, 'computer_it', true, true)
on conflict (id) do update set
  label = excluded.label,
  sort_order = excluded.sort_order,
  parent_id = excluded.parent_id,
  is_open_ended = excluded.is_open_ended,
  is_selectable = excluded.is_selectable,
  is_active = true;
