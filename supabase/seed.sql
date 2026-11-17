-- Dev-only seed so the M2 demo works out of the box.
-- Owner: owner@guardian.dev / guardianpass  (local only; never used in prod).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated', 'owner@guardian.dev',
  extensions.crypt('guardianpass', extensions.gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}', '{}',
  '', '', '', '', '', '', '', ''
)
on conflict (id) do nothing;

insert into public.profiles (id, display_name, region_code, anti_stalking_attested_at)
values ('11111111-1111-1111-1111-111111111111', 'Dev Owner', 'IN', now())
on conflict (id) do nothing;

insert into public.emergency_contacts (id, owner_id, name, contact_email, status)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  'Dev Contact', 'contact@guardian.dev', 'verified'
)
on conflict (id) do nothing;
