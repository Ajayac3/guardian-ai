-- M7: a device's FCM token must be unique so registration can upsert on it.
-- Non-partial unique index: Postgres permits multiple NULLs (a device may have
-- only an apns_token), while any concrete fcm_token is unique.
create unique index if not exists push_tokens_fcm_token_key
  on public.push_tokens (fcm_token);
