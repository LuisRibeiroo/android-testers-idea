-- 001: Initial TesterLoop schema (Postgres 15+ / Supabase self-hosted on VPS)

create extension if not exists pgcrypto;
create extension if not exists btree_gist;

-- ===== Identity =====
create table if not exists public.profiles (
  id            uuid primary key references auth.users on delete cascade,
  display_name  text not null,
  avatar_url    text,
  locale        text not null default 'pt-BR',
  timezone      text not null default 'America/Sao_Paulo',
  reputation    numeric(4,3) not null default 1.000 check (reputation >= 0 and reputation <= 1),
  fcm_token     text,
  banned_at     timestamptz,
  created_at    timestamptz not null default now()
);

create table if not exists public.devices (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles(id) on delete cascade,
  android_id_hash   text not null unique,
  model             text,
  sdk_int           int,
  integrity_ok_at   timestamptz,
  last_seen_at      timestamptz not null default now(),
  created_at        timestamptz not null default now()
);

create index if not exists devices_user_idx on public.devices(user_id);

-- ===== Apps & Campaigns =====
create table if not exists public.apps (
  id                   uuid primary key default gen_random_uuid(),
  owner_id             uuid not null references public.profiles(id) on delete cascade,
  package_name         text not null unique,
  name                 text not null,
  short_description    text not null check (char_length(short_description) <= 80),
  description          text,
  category             text,
  icon_path            text,
  screenshots          text[] not null default '{}',
  play_optin_url       text not null,
  app_key              text not null unique,
  signing_cert_sha256  text,
  sdk_debug_ok_at      timestamptz,
  sdk_verified_at      timestamptz,
  created_at           timestamptz not null default now()
);

create index if not exists apps_owner_idx on public.apps(owner_id);

do $$ begin
  create type public.campaign_status as enum
    ('draft', 'recruiting', 'in_progress', 'completed', 'failed', 'cancelled');
exception when duplicate_object then null; end $$;

create table if not exists public.campaigns (
  id                 uuid primary key default gen_random_uuid(),
  app_id             uuid not null references public.apps(id) on delete cascade,
  status             public.campaign_status not null default 'draft',
  slots              int not null default 12,
  buffer_slots       int not null default 3,
  required_days      int not null default 14,
  min_active_days    int not null default 10,
  cost_points        int not null default 120,
  active_count       int not null default 0,
  completed_count    int not null default 0,
  published_at       timestamptz,
  deadline_at        timestamptz,
  completed_at       timestamptz,
  created_at         timestamptz not null default now()
);

create unique index if not exists one_live_campaign_per_app
  on public.campaigns(app_id)
  where status in ('recruiting', 'in_progress');

create index if not exists campaigns_recent
  on public.campaigns(published_at desc)
  where status = 'recruiting';

create index if not exists campaigns_popular
  on public.campaigns(active_count desc, published_at asc)
  where status = 'recruiting';

do $$ begin
  create type public.enrollment_status as enum
    ('pending', 'active', 'at_risk', 'completed', 'dropped', 'rejected');
exception when duplicate_object then null; end $$;

create table if not exists public.enrollments (
  id                 uuid primary key default gen_random_uuid(),
  campaign_id        uuid not null references public.campaigns(id) on delete cascade,
  tester_id          uuid not null references public.profiles(id) on delete cascade,
  device_id          uuid not null references public.devices(id),
  kind               text not null default 'tester' check (kind in ('tester', 'owner_validation')),
  status             public.enrollment_status not null default 'pending',
  enrolled_at        timestamptz not null default now(),
  first_handshake_at timestamptz,
  streak_days        int not null default 0,
  active_days        int not null default 0,
  last_present_day   date,
  last_active_day    date,
  completed_at       timestamptz,
  dropped_at         timestamptz,
  drop_reason        text,
  unique (campaign_id, tester_id)
);

create index if not exists enrollments_tester_idx on public.enrollments(tester_id, status);
create index if not exists enrollments_campaign_idx on public.enrollments(campaign_id, status);

create table if not exists public.daily_activity (
  enrollment_id      uuid not null references public.enrollments(id) on delete cascade,
  day                date not null,
  present            boolean not null default false,
  foreground_seconds int not null default 0,
  sessions           int not null default 0,
  sources            text[] not null default '{}',
  primary key (enrollment_id, day)
);

-- ===== Raw SDK Events (partitioned by month, default partition included) =====
create table if not exists public.sdk_events (
  id            bigint generated always as identity,
  received_at   timestamptz not null default now(),
  app_id        uuid not null,
  enrollment_id uuid,
  install_id    text not null,
  event_id      text not null,
  type          text not null check (type in ('handshake', 'session', 'ping')),
  payload       jsonb not null,
  primary key (id, received_at)
) partition by range (received_at);

create table if not exists public.sdk_events_default
  partition of public.sdk_events default;

create index if not exists sdk_events_dedupe_idx
  on public.sdk_events(app_id, install_id, event_id);

-- ===== Points Ledger (immutable append-only) =====
do $$ begin
  create type public.ledger_kind as enum (
    'earn_pending',
    'release',
    'forfeit',
    'spend_campaign',
    'refund_campaign',
    'bonus_welcome',
    'bonus_completion',
    'bonus_feedback',
    'admin_adjust',
    'expire'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.points_ledger (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        public.ledger_kind not null,
  bucket      text not null check (bucket in ('pending', 'available')),
  amount      int not null,
  ref_type    text,
  ref_id      uuid,
  created_at  timestamptz not null default now()
);

create index if not exists points_ledger_user_idx on public.points_ledger(user_id, created_at desc);

create or replace view public.wallet as
  select
    user_id,
    coalesce(sum(amount) filter (where bucket = 'available'), 0)::int as available,
    coalesce(sum(amount) filter (where bucket = 'pending'), 0)::int   as pending,
    max(created_at) as last_activity_at
  from public.points_ledger
  group by user_id;

-- ===== Feedback =====
create table if not exists public.feedback (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null unique references public.enrollments(id) on delete cascade,
  rating        int not null check (rating between 1 and 5),
  liked         text,
  issues        text,
  suggestion    text,
  status        text not null default 'submitted' check (status in ('submitted', 'approved', 'rejected')),
  created_at    timestamptz not null default now()
);

-- ===== Featured & Billing =====
create table if not exists public.featured_products (
  id              text primary key,
  duration_hours  int not null,
  reference_usd   numeric(10,2),
  active          boolean not null default true
);

create table if not exists public.purchases (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  product_id      text not null references public.featured_products(id),
  purchase_token  text not null unique,
  order_id        text,
  state           text not null check (state in ('pending', 'purchased', 'consumed', 'refunded')),
  raw             jsonb,
  created_at      timestamptz not null default now()
);

create table if not exists public.featured_bookings (
  id           uuid primary key default gen_random_uuid(),
  campaign_id  uuid not null references public.campaigns(id) on delete cascade,
  slot_index   int not null check (slot_index between 1 and 3),
  period       tstzrange not null,
  purchase_id  uuid references public.purchases(id),
  status       text not null default 'reserved' check (status in ('reserved', 'confirmed', 'cancelled')),
  expires_at   timestamptz,
  created_at   timestamptz not null default now(),
  exclude using gist (slot_index with =, period with &&) where (status <> 'cancelled')
);

create table if not exists public.featured_credits (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  remaining_sec int not null check (remaining_sec >= 0),
  source_booking_id uuid references public.featured_bookings(id),
  created_at    timestamptz not null default now()
);

-- ===== Config & Abuse Reports =====
create table if not exists public.config (
  key   text primary key,
  value jsonb not null
);

create table if not exists public.abuse_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  target_type text not null,
  target_id   uuid not null,
  reason      text not null,
  created_at  timestamptz not null default now()
);

-- ===== Public Feed Views =====
create or replace view public.public_profiles as
  select id, display_name, avatar_url, reputation
  from public.profiles
  where banned_at is null;

create or replace view public.feed_campaigns as
  select
    c.id,
    c.app_id,
    a.owner_id,
    a.package_name,
    a.name,
    a.short_description,
    a.description,
    a.category,
    a.icon_path,
    a.screenshots,
    a.play_optin_url,
    a.signing_cert_sha256,
    c.status,
    c.slots,
    c.buffer_slots,
    c.required_days,
    c.min_active_days,
    c.cost_points,
    c.active_count,
    c.completed_count,
    c.published_at,
    c.deadline_at
  from public.campaigns c
  join public.apps a on a.id = c.app_id;

-- ===== Counter Triggers =====
create or replace function public.sync_campaign_counters()
returns trigger
language plpgsql
security definer
as $$
declare
  v_campaign_id uuid;
begin
  v_campaign_id := coalesce(new.campaign_id, old.campaign_id);
  update public.campaigns
  set
    active_count = (
      select count(*) from public.enrollments
      where campaign_id = v_campaign_id
        and kind = 'tester'
        and status in ('active', 'at_risk')
    ),
    completed_count = (
      select count(*) from public.enrollments
      where campaign_id = v_campaign_id
        and kind = 'tester'
        and status = 'completed'
    )
  where id = v_campaign_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_campaign_counters on public.enrollments;
create trigger trg_sync_campaign_counters
after insert or update of status or delete on public.enrollments
for each row execute function public.sync_campaign_counters();
