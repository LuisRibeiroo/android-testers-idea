-- 002: Row Level Security (RLS) & Atomic RPCs

alter table public.profiles enable row level security;
alter table public.devices enable row level security;
alter table public.apps enable row level security;
alter table public.campaigns enable row level security;
alter table public.enrollments enable row level security;
alter table public.daily_activity enable row level security;
alter table public.sdk_events enable row level security;
alter table public.points_ledger enable row level security;
alter table public.feedback enable row level security;
alter table public.featured_products enable row level security;
alter table public.purchases enable row level security;
alter table public.featured_bookings enable row level security;
alter table public.featured_credits enable row level security;
alter table public.config enable row level security;
alter table public.abuse_reports enable row level security;

-- Profiles
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id)
  with check (auth.uid() = id);

-- Devices (read-only for owner; writes via Edge Function)
create policy "devices_select_own" on public.devices
  for select using (auth.uid() = user_id);

-- Apps
create policy "apps_select_public_or_owner" on public.apps
  for select using (
    auth.uid() = owner_id
    or exists (
      select 1 from public.campaigns c
      where c.app_id = apps.id and c.status in ('recruiting', 'in_progress')
    )
  );

create policy "apps_insert_owner" on public.apps
  for insert with check (auth.uid() = owner_id);

create policy "apps_update_owner" on public.apps
  for update using (auth.uid() = owner_id);

-- Campaigns
create policy "campaigns_select_live_or_owner" on public.campaigns
  for select using (
    status in ('recruiting', 'in_progress')
    or exists (select 1 from public.apps a where a.id = campaigns.app_id and a.owner_id = auth.uid())
  );

create policy "campaigns_insert_draft_owner" on public.campaigns
  for insert with check (
    status = 'draft'
    and exists (select 1 from public.apps a where a.id = campaigns.app_id and a.owner_id = auth.uid())
  );

-- Enrollments & Daily Activity (writes only by backend)
create policy "enrollments_select_tester_or_owner" on public.enrollments
  for select using (
    auth.uid() = tester_id
    or exists (
      select 1 from public.campaigns c
      join public.apps a on a.id = c.app_id
      where c.id = enrollments.campaign_id and a.owner_id = auth.uid()
    )
  );

create policy "daily_activity_select_tester_or_owner" on public.daily_activity
  for select using (
    exists (
      select 1 from public.enrollments e
      left join public.campaigns c on c.id = e.campaign_id
      left join public.apps a on a.id = c.app_id
      where e.id = daily_activity.enrollment_id
        and (e.tester_id = auth.uid() or a.owner_id = auth.uid())
    )
  );

-- Points Ledger
create policy "points_ledger_select_own" on public.points_ledger
  for select using (auth.uid() = user_id);

-- Feedback
create policy "feedback_select_tester_or_owner" on public.feedback
  for select using (
    exists (
      select 1 from public.enrollments e
      join public.campaigns c on c.id = e.campaign_id
      join public.apps a on a.id = c.app_id
      where e.id = feedback.enrollment_id
        and (e.tester_id = auth.uid() or a.owner_id = auth.uid())
    )
  );

-- Featured & Config
create policy "featured_products_public_read" on public.featured_products
  for select using (active = true);

create policy "featured_bookings_public_read" on public.featured_bookings
  for select using (status = 'confirmed');

create policy "purchases_select_own" on public.purchases
  for select using (auth.uid() = user_id);

create policy "featured_credits_select_own" on public.featured_credits
  for select using (auth.uid() = user_id);

create policy "config_public_read" on public.config
  for select using (true);

create policy "abuse_reports_insert_own" on public.abuse_reports
  for insert with check (auth.uid() = reporter_id);

-- ===== Atomic RPCs =====

create or replace function public.publish_campaign(p_app_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_app record;
  v_rules jsonb;
  v_cost int;
  v_slots int;
  v_buffer int;
  v_req_days int;
  v_min_active int;
  v_available int;
  v_campaign_id uuid;
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;

  select * into v_app from public.apps where id = p_app_id for update;
  if not found or v_app.owner_id <> v_uid then
    raise exception 'app_not_found_or_forbidden';
  end if;

  if v_app.sdk_verified_at is null then
    raise exception 'sdk_not_verified';
  end if;

  if exists (
    select 1 from public.campaigns
    where app_id = p_app_id and status in ('recruiting', 'in_progress')
  ) then
    raise exception 'campaign_already_live';
  end if;

  select value into v_rules from public.config where key = 'points';
  v_cost := coalesce((v_rules->>'cost_points')::int, 120);
  v_slots := coalesce((v_rules->>'slots')::int, 12);
  v_buffer := coalesce((v_rules->>'buffer_slots')::int, 3);
  v_req_days := coalesce((v_rules->>'required_days')::int, 14);
  v_min_active := coalesce((v_rules->>'min_active_days')::int, 10);

  -- Lock user row to prevent concurrent double-spend
  perform 1 from public.profiles where id = v_uid for update;

  select coalesce(sum(amount) filter (where bucket = 'available'), 0)::int
  into v_available
  from public.points_ledger
  where user_id = v_uid;

  if v_available < v_cost then
    raise exception 'insufficient_points';
  end if;

  insert into public.campaigns (
    app_id, status, slots, buffer_slots, required_days, min_active_days,
    cost_points, published_at, deadline_at
  ) values (
    p_app_id, 'recruiting', v_slots, v_buffer, v_req_days, v_min_active,
    v_cost, now(), now() + interval '45 days'
  )
  returning id into v_campaign_id;

  insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
  values (v_uid, 'spend_campaign', 'available', -v_cost, 'campaign', v_campaign_id);

  return v_campaign_id;
end;
$$;

create or replace function public.cancel_campaign(p_campaign_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_camp record;
  v_occupied int;
  v_total_slots int;
  v_refund int;
  v_enrollment record;
  v_pending_earned int;
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;

  select c.*, a.owner_id
  into v_camp
  from public.campaigns c
  join public.apps a on a.id = c.app_id
  where c.id = p_campaign_id
  for update;

  if not found or v_camp.owner_id <> v_uid then
    raise exception 'campaign_not_found_or_forbidden';
  end if;

  if v_camp.status not in ('draft', 'recruiting', 'in_progress') then
    raise exception 'campaign_cannot_be_cancelled';
  end if;

  v_total_slots := greatest(v_camp.slots, 1);
  v_occupied := least(v_total_slots, v_camp.active_count + v_camp.completed_count);

  if v_camp.status = 'draft' then
    v_refund := 0;
  elsif v_occupied = 0 then
    v_refund := v_camp.cost_points;
  else
    -- TQ-6: Proportional refund for unfilled slots
    v_refund := floor(v_camp.cost_points * ((v_total_slots - v_occupied)::numeric / v_total_slots));
  end if;

  update public.campaigns set status = 'cancelled' where id = p_campaign_id;

  if v_refund > 0 then
    insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
    values (v_uid, 'refund_campaign', 'available', v_refund, 'campaign', p_campaign_id);
  end if;

  -- Release accumulated pending points to active testers
  for v_enrollment in
    select id, tester_id, active_days
    from public.enrollments
    where campaign_id = p_campaign_id and kind = 'tester' and status in ('active', 'at_risk')
  loop
    v_pending_earned := v_enrollment.active_days;
    if v_pending_earned > 0 then
      insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
      values
        (v_enrollment.tester_id, 'release', 'pending', -v_pending_earned, 'enrollment', v_enrollment.id),
        (v_enrollment.tester_id, 'release', 'available', v_pending_earned, 'enrollment', v_enrollment.id);
    end if;
    update public.enrollments set status = 'dropped', dropped_at = now(), drop_reason = 'campaign_cancelled'
    where id = v_enrollment.id;
  end loop;

  return v_refund;
end;
$$;

create or replace function public.enroll_in_campaign(p_campaign_id uuid, p_device_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_camp record;
  v_active_enrollments int;
  v_rep numeric;
  v_max_enrollments int;
  v_enrollment_id uuid;
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;

  select c.*, a.owner_id
  into v_camp
  from public.campaigns c
  join public.apps a on a.id = c.app_id
  where c.id = p_campaign_id
  for update;

  if not found or v_camp.status <> 'recruiting' then
    raise exception 'campaign_not_recruiting';
  end if;

  if v_camp.owner_id = v_uid then
    raise exception 'cannot_test_own_app';
  end if;

  if (v_camp.active_count + v_camp.completed_count) >= (v_camp.slots + v_camp.buffer_slots) then
    raise exception 'campaign_full';
  end if;

  if not exists (
    select 1 from public.devices where id = p_device_id and user_id = v_uid
  ) then
    raise exception 'invalid_device';
  end if;

  select reputation into v_rep from public.profiles where id = v_uid;
  v_max_enrollments := case when coalesce(v_rep, 1.0) < 0.5 then 5 else 20 end;

  select count(*) into v_active_enrollments
  from public.enrollments
  where tester_id = v_uid and status in ('pending', 'active', 'at_risk');

  if v_active_enrollments >= v_max_enrollments then
    raise exception 'enrollment_limit_reached';
  end if;

  insert into public.enrollments (campaign_id, tester_id, device_id, kind, status)
  values (p_campaign_id, v_uid, p_device_id, 'tester', 'pending')
  returning id into v_enrollment_id;

  return v_enrollment_id;
end;
$$;

create or replace function public.submit_feedback(
  p_enrollment_id uuid,
  p_rating int,
  p_liked text,
  p_issues text,
  p_suggestion text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_enr record;
  v_feedback_id uuid;
  v_total_len int;
  v_status text;
  v_bonus int := 2;
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;

  select * into v_enr from public.enrollments where id = p_enrollment_id for update;
  if not found or v_enr.tester_id <> v_uid then
    raise exception 'enrollment_not_found_or_forbidden';
  end if;

  if v_enr.status not in ('active', 'at_risk', 'completed') then
    raise exception 'enrollment_not_eligible';
  end if;

  v_total_len := coalesce(char_length(trim(p_liked)), 0)
               + coalesce(char_length(trim(p_issues)), 0)
               + coalesce(char_length(trim(p_suggestion)), 0);
  v_status := case when v_total_len >= 30 then 'approved' else 'submitted' end;

  insert into public.feedback (enrollment_id, rating, liked, issues, suggestion, status)
  values (p_enrollment_id, p_rating, p_liked, p_issues, p_suggestion, v_status)
  returning id into v_feedback_id;

  if v_status = 'approved' then
    insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
    values (v_uid, 'bonus_feedback', 'available', v_bonus, 'feedback', v_feedback_id);
  end if;

  return v_feedback_id;
end;
$$;

create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;
  delete from auth.users where id = v_uid;
end;
$$;
