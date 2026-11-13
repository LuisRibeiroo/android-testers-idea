-- 003: Scheduled pg_cron jobs (including 360-day points expiration OQ-7)

create extension if not exists pg_cron;

create or replace function public.job_rollup_days()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enr record;
  v_local_yesterday date;
  v_act record;
  v_rules jsonb;
  v_min_fg int;
  v_max_abs int;
  v_pts_day int;
  v_absence int;
begin
  select value into v_rules from public.config where key = 'points';
  v_min_fg := coalesce((v_rules->>'min_foreground_seconds')::int, 60);
  v_max_abs := coalesce((v_rules->>'max_absence_days')::int, 2);
  v_pts_day := coalesce((v_rules->>'points_per_active_day')::int, 1);

  -- Expire pending enrollments with no handshake after 72h
  update public.enrollments
  set status = 'dropped', dropped_at = now(), drop_reason = 'handshake_timeout'
  where status = 'pending' and enrolled_at < now() - interval '72 hours';

  for v_enr in
    select e.*, p.timezone
    from public.enrollments e
    join public.profiles p on p.id = e.tester_id
    where e.kind = 'tester' and e.status in ('active', 'at_risk')
  loop
    v_local_yesterday := ((now() at time zone coalesce(v_enr.timezone, 'America/Sao_Paulo'))::date - 1);

    if v_enr.last_present_day is not null and v_enr.last_present_day >= v_local_yesterday then
      continue;
    end if;

    select * into v_act
    from public.daily_activity
    where enrollment_id = v_enr.id and day = v_local_yesterday;

    if found and v_act.present then
      update public.enrollments
      set
        streak_days = streak_days + 1,
        active_days = active_days + case when v_act.foreground_seconds >= v_min_fg then 1 else 0 end,
        last_present_day = v_local_yesterday,
        last_active_day = case when v_act.foreground_seconds >= v_min_fg then v_local_yesterday else last_active_day end,
        status = 'active'
      where id = v_enr.id;

      if v_act.foreground_seconds >= v_min_fg then
        insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
        values (v_enr.tester_id, 'earn_pending', 'pending', v_pts_day, 'enrollment', v_enr.id);
      end if;
    else
      v_absence := coalesce(v_local_yesterday - v_enr.last_present_day, 1);
      if v_absence > v_max_abs then
        update public.enrollments
        set status = 'dropped', dropped_at = now(), drop_reason = 'absence_limit'
        where id = v_enr.id;

        if v_enr.active_days > 0 then
          insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
          values (v_enr.tester_id, 'forfeit', 'pending', -v_enr.active_days, 'enrollment', v_enr.id);
        end if;
      else
        update public.enrollments set status = 'at_risk' where id = v_enr.id;
      end if;
    end if;
  end loop;
end;
$$;

create or replace function public.job_complete_enrollments()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_enr record;
  v_rules jsonb;
  v_bonus int;
begin
  select value into v_rules from public.config where key = 'points';
  v_bonus := coalesce((v_rules->>'bonus_completion')::int, 3);

  for v_enr in
    select e.*, c.required_days, c.min_active_days
    from public.enrollments e
    join public.campaigns c on c.id = e.campaign_id
    where e.kind = 'tester'
      and e.status in ('active', 'at_risk')
      and e.streak_days >= c.required_days
      and e.active_days >= c.min_active_days
  loop
    update public.enrollments
    set status = 'completed', completed_at = now()
    where id = v_enr.id;

    if v_enr.active_days > 0 then
      insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
      values
        (v_enr.tester_id, 'release', 'pending', -v_enr.active_days, 'enrollment', v_enr.id),
        (v_enr.tester_id, 'release', 'available', v_enr.active_days, 'enrollment', v_enr.id);
    end if;

    insert into public.points_ledger (user_id, kind, bucket, amount, ref_type, ref_id)
    values (v_enr.tester_id, 'bonus_completion', 'available', v_bonus, 'enrollment', v_enr.id);
  end loop;
end;
$$;

create or replace function public.job_complete_campaigns()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_camp record;
  v_booking record;
  v_rem_sec int;
begin
  -- Transition recruiting -> in_progress when full
  update public.campaigns
  set status = 'in_progress'
  where status = 'recruiting'
    and (active_count + completed_count) >= (slots + buffer_slots);

  -- Complete campaigns that reached >= slots completed enrollments
  for v_camp in
    select c.*, a.owner_id
    from public.campaigns c
    join public.apps a on a.id = c.app_id
    where c.status in ('recruiting', 'in_progress')
      and c.completed_count >= c.slots
  loop
    update public.campaigns
    set status = 'completed', completed_at = now()
    where id = v_camp.id;

    -- TQ-7: Convert unused Featured duration into credit for a future campaign
    for v_booking in
      select * from public.featured_bookings
      where campaign_id = v_camp.id
        and status = 'confirmed'
        and upper(period) > now()
    loop
      v_rem_sec := extract(epoch from (upper(v_booking.period) - greatest(now(), lower(v_booking.period))))::int;
      if v_rem_sec > 0 then
        insert into public.featured_credits (user_id, remaining_sec, source_booking_id)
        values (v_camp.owner_id, v_rem_sec, v_booking.id);
      end if;
      update public.featured_bookings set status = 'cancelled' where id = v_booking.id;
    end loop;
  end loop;

  -- Fail campaigns past deadline
  update public.campaigns
  set status = 'failed'
  where status in ('recruiting', 'in_progress')
    and deadline_at is not null
    and deadline_at < now();
end;
$$;

create or replace function public.job_expire_points()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
  v_rules jsonb;
  v_expire_days int;
begin
  select value into v_rules from public.config where key = 'points';
  -- OQ-7: Points expire after 360 days of inactivity
  v_expire_days := coalesce((v_rules->>'expire_days')::int, 360);

  for v_row in
    select user_id, available
    from public.wallet
    where available > 0
      and last_activity_at < now() - make_interval(days => v_expire_days)
  loop
    insert into public.points_ledger (user_id, kind, bucket, amount, ref_type)
    values (v_row.user_id, 'expire', 'available', -v_row.available, 'inactivity_360d');
  end loop;
end;
$$;

create or replace function public.job_featured_rotation()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Release expired unpaid reservations
  update public.featured_bookings
  set status = 'cancelled'
  where status = 'reserved'
    and expires_at is not null
    and expires_at < now();
end;
$$;

-- Schedule jobs (safe upsert via cron.schedule)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('rollup_days', '5 * * * *', 'select public.job_rollup_days()');
    perform cron.schedule('complete_enrollments', '10 * * * *', 'select public.job_complete_enrollments()');
    perform cron.schedule('complete_campaigns', '15 * * * *', 'select public.job_complete_campaigns()');
    perform cron.schedule('expire_points', '0 3 * * *', 'select public.job_expire_points()');
    perform cron.schedule('featured_rotation', '*/5 * * * *', 'select public.job_featured_rotation()');
  end if;
end $$;
