-- Initial runtime configuration & Featured catalog

insert into public.config (key, value)
values (
  'points',
  jsonb_build_object(
    'required_days', 14,
    'min_active_days', 10,
    'min_foreground_seconds', 60,
    'max_absence_days', 2,
    'slots', 12,
    'buffer_slots', 3,
    'cost_points', 120,
    'points_per_active_day', 1,
    'bonus_completion', 3,
    'bonus_feedback', 2,
    'bonus_welcome', 10,
    'expire_days', 360
  )
)
on conflict (key) do update set value = excluded.value;

insert into public.config (key, value)
values (
  'community',
  jsonb_build_object(
    'google_group_url', 'https://groups.google.com/g/testerloop-testers',
    'reddit_community_url', 'https://www.reddit.com/r/AndroidAppTesters',
    'hub_account_type', 'personal'
  )
)
on conflict (key) do update set value = excluded.value;

insert into public.featured_products (id, duration_hours, reference_usd, active)
values
  ('featured_24h', 24, 4.99, true),
  ('featured_72h', 72, 11.99, true),
  ('featured_7d', 168, 24.99, true)
on conflict (id) do update set
  duration_hours = excluded.duration_hours,
  reference_usd = excluded.reference_usd,
  active = excluded.active;
