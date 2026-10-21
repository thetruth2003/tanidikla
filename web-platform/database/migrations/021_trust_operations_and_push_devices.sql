create table if not exists review_moderation_events (
  id bigint generated always as identity primary key,
  review_id uuid not null references reviews(id) on delete cascade,
  actor_id uuid references users(id) on delete set null,
  from_status text,
  to_status text not null,
  note text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists review_moderation_events_review_idx
  on review_moderation_events (review_id, id desc);

alter table push_delivery_queue add column if not exists device_token_id uuid references device_push_tokens(id) on delete cascade;

create or replace function enqueue_notification_push() returns trigger language plpgsql as $$
begin
  insert into push_delivery_queue(notification_id,user_id,platform,payload,status,device_token_id)
  select new.id,new.user_id,d.platform,
         jsonb_build_object('notification_id',new.id,'type',new.type,'title',new.title,'body',new.body,'data',new.data),
         'pending',d.id
  from device_push_tokens d where d.user_id=new.user_id and d.revoked_at is null;
  return new;
end $$;
drop trigger if exists notifications_enqueue_push on notifications;
create trigger notifications_enqueue_push after insert on notifications
for each row execute function enqueue_notification_push();

insert into permissions (code, description) values
  ('reviews.view', 'Değerlendirme kayıtlarını görüntüleme'),
  ('beta.view', 'Kapalı beta kayıtlarını görüntüleme')
on conflict (code) do update set description = excluded.description;
insert into role_permissions (role, permission_code)
select role, permission_code
from (values ('moderator'),('admin'),('super_admin')) roles(role)
cross join (values ('reviews.view'),('beta.view')) permissions(permission_code)
on conflict do nothing;
