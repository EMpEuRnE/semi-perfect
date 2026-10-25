begin;

create or replace function public.join_mission(p_mission_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_mission public.missions%rowtype;
  v_user_mission_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select * into v_mission from public.missions where id = p_mission_id;
  if not found or v_mission.status <> 'active'
    or (v_mission.starts_at is not null and v_mission.starts_at > now())
    or (v_mission.ends_at is not null and v_mission.ends_at < now()) then
    raise exception 'Mission is not open for joining' using errcode = '22023';
  end if;

  insert into public.user_missions (user_id, mission_id)
  values (v_user_id, p_mission_id)
  on conflict (user_id, mission_id) do nothing
  returning id into v_user_mission_id;
  if v_user_mission_id is null then
    select id into v_user_mission_id from public.user_missions
    where user_id = v_user_id and mission_id = p_mission_id;
  end if;
  return v_user_mission_id;
end;
$$;

create or replace function public.join_challenge(p_challenge_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_challenge public.challenges%rowtype;
  v_campaign_status text;
  v_campaign_starts_at timestamptz;
  v_campaign_ends_at timestamptz;
  v_brand_status text;
  v_participant_id uuid;
  v_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  -- Serialize joins for this challenge so its participant limit cannot race.
  select * into v_challenge from public.challenges
  where id = p_challenge_id for update;
  if not found then
    raise exception 'Challenge not found' using errcode = '22023';
  end if;

  select cam.status, cam.starts_at, cam.ends_at, b.status
  into v_campaign_status, v_campaign_starts_at, v_campaign_ends_at, v_brand_status
  from public.campaigns cam join public.brands b on b.id = cam.brand_id
  where cam.id = v_challenge.campaign_id and cam.brand_id = v_challenge.brand_id;
  if v_challenge.status <> 'active' or v_campaign_status <> 'active' or v_brand_status <> 'active'
    or (v_challenge.starts_at is not null and v_challenge.starts_at > now())
    or (v_challenge.ends_at is not null and v_challenge.ends_at < now())
    or (v_campaign_starts_at is not null and v_campaign_starts_at > now())
    or (v_campaign_ends_at is not null and v_campaign_ends_at < now()) then
    raise exception 'Challenge is not open for joining' using errcode = '22023';
  end if;

  select id into v_participant_id from public.challenge_participants
  where challenge_id = p_challenge_id and user_id = v_user_id;
  if v_participant_id is not null then
    return v_participant_id;
  end if;

  if v_challenge.participant_limit is not null then
    select count(*) into v_count from public.challenge_participants
    where challenge_id = p_challenge_id;
    if v_count >= v_challenge.participant_limit then
      raise exception 'Challenge has reached its participant limit' using errcode = '22023';
    end if;
  end if;

  insert into public.challenge_participants (challenge_id, user_id)
  values (p_challenge_id, v_user_id)
  returning id into v_participant_id;
  return v_participant_id;
end;
$$;

create or replace function public.review_activity(
  p_activity_id uuid,
  p_approved boolean,
  p_reviewer_note text default null
)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_reviewer_id uuid := (select auth.uid());
  v_activity public.activities%rowtype;
  v_user_mission public.user_missions%rowtype;
  v_participant public.challenge_participants%rowtype;
  v_mission public.missions%rowtype;
  v_challenge public.challenges%rowtype;
  v_new_progress numeric(14, 3);
  v_now timestamptz := now();
  v_transaction_id uuid;
begin
  if v_reviewer_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_approved is null then
    raise exception 'Approval decision is required' using errcode = '22023';
  end if;

  select * into v_activity from public.activities where id = p_activity_id for update;
  if not found or v_activity.verification_status <> 'pending' then
    raise exception 'Activity is missing or already reviewed' using errcode = '22023';
  end if;
  if v_activity.user_id = v_reviewer_id then
    raise exception 'Users cannot review their own activity' using errcode = '42501';
  end if;

  if v_activity.user_mission_id is not null then
    select * into v_user_mission from public.user_missions
    where id = v_activity.user_mission_id for update;
    select * into v_mission from public.missions where id = v_user_mission.mission_id;
    if not (select private.is_admin()) then
      raise exception 'Only an admin can review mission activity' using errcode = '42501';
    end if;
    if p_approved and (v_activity.activity_type <> v_mission.activity_type
      or v_activity.unit <> v_mission.target_unit) then
      raise exception 'Activity type or unit does not match the mission' using errcode = '22023';
    end if;
  else
    select * into v_participant from public.challenge_participants
    where id = v_activity.challenge_participant_id for update;
    select * into v_challenge from public.challenges where id = v_participant.challenge_id;
    if not (select private.is_admin()) and not (
      select private.is_brand_member(v_challenge.brand_id, array['owner', 'manager'])
    ) then
      raise exception 'Only the challenge brand manager or an admin can review this activity'
        using errcode = '42501';
    end if;
    if p_approved and (v_activity.activity_type <> v_challenge.activity_type
      or v_activity.unit <> v_challenge.target_unit) then
      raise exception 'Activity type or unit does not match the challenge' using errcode = '22023';
    end if;
  end if;

  update public.activities
  set verification_status = case when p_approved then 'approved' else 'rejected' end,
      reviewer_note = nullif(left(btrim(coalesce(p_reviewer_note, '')), 1000), ''),
      reviewed_by = v_reviewer_id,
      reviewed_at = v_now
  where id = p_activity_id;

  if not p_approved then
    return null;
  end if;

  -- Locking the participation row prevents concurrent reviews from losing progress.
  -- Locking the profile serializes new credits against concurrent reward redemptions.
  if v_activity.user_mission_id is not null then
    if v_user_mission.status in ('joined', 'in_progress') then
      v_new_progress := least(v_mission.target_value, v_user_mission.progress_value + v_activity.value);
      update public.user_missions
      set progress_value = v_new_progress,
          status = case when v_new_progress >= v_mission.target_value then 'completed' else 'in_progress' end,
          completed_at = case when v_new_progress >= v_mission.target_value then v_now else null end
      where id = v_user_mission.id;
      if v_new_progress >= v_mission.target_value then
        perform 1 from public.profiles where id = v_activity.user_id for update;
        insert into public.point_transactions
          (user_id, actor_id, amount, transaction_type, source, reference_id, activity_id, description)
        values
          (v_activity.user_id, v_reviewer_id, v_mission.points, 'earn', 'mission',
            v_activity.id, v_activity.id, 'Mission completed: ' || v_mission.title)
        returning id into v_transaction_id;
      end if;
    end if;
  else
    if v_participant.status in ('joined', 'in_progress') then
      v_new_progress := least(v_challenge.target_value, v_participant.progress_value + v_activity.value);
      update public.challenge_participants
      set progress_value = v_new_progress,
          status = case when v_new_progress >= v_challenge.target_value then 'completed' else 'in_progress' end,
          completed_at = case when v_new_progress >= v_challenge.target_value then v_now else null end
      where id = v_participant.id;
      if v_new_progress >= v_challenge.target_value then
        perform 1 from public.profiles where id = v_activity.user_id for update;
        insert into public.point_transactions
          (user_id, actor_id, amount, transaction_type, source, reference_id, activity_id, description)
        values
          (v_activity.user_id, v_reviewer_id, v_challenge.reward_points, 'earn', 'challenge',
            v_activity.id, v_activity.id, 'Challenge completed: ' || v_challenge.title)
        returning id into v_transaction_id;
      end if;
    end if;
  end if;
  return v_transaction_id;
end;
$$;

create or replace function public.redeem_reward(p_reward_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_reward public.rewards%rowtype;
  v_balance bigint;
  v_redemption_id uuid;
  v_code text;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  -- The profile row acts as a per-user wallet lock while balance is checked and debited.
  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    raise exception 'Profile not found' using errcode = '23503';
  end if;
  select * into v_reward from public.rewards where id = p_reward_id for update;
  if not found or v_reward.status <> 'active'
    or (v_reward.expires_at is not null and v_reward.expires_at <= now())
    or (v_reward.brand_id is not null and not exists (
      select 1 from public.brands b where b.id = v_reward.brand_id and b.status = 'active'
    )) then
    raise exception 'Reward is not available' using errcode = '22023';
  end if;
  if v_reward.stock is not null and v_reward.stock <= 0 then
    raise exception 'Reward is out of stock' using errcode = '22023';
  end if;

  select coalesce(sum(pt.amount), 0) into v_balance
  from public.point_transactions pt where pt.user_id = v_user_id;
  if v_balance < v_reward.points_required then
    raise exception 'Not enough points' using errcode = '22023';
  end if;

  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
  insert into public.redemptions (user_id, reward_id, points_spent, redemption_code)
  values (v_user_id, v_reward.id, v_reward.points_required, v_code)
  returning id into v_redemption_id;
  if v_reward.stock is not null then
    update public.rewards set stock = stock - 1 where id = v_reward.id;
  end if;
  insert into public.point_transactions
    (user_id, actor_id, amount, transaction_type, source, reference_id, redemption_id, description)
  values
    (v_user_id, v_user_id, -v_reward.points_required, 'spend', 'redemption',
      v_redemption_id, v_redemption_id, 'Reward redeemed: ' || v_reward.title);
  return v_redemption_id;
end;
$$;

create or replace function public.fulfill_redemption(p_redemption_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_redemption public.redemptions%rowtype;
  v_reward public.rewards%rowtype;
begin
  if v_actor_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  select * into v_redemption from public.redemptions where id = p_redemption_id for update;
  if not found then
    raise exception 'Redemption not found' using errcode = '22023';
  end if;
  select * into v_reward from public.rewards where id = v_redemption.reward_id;
  if not (select private.is_admin()) and (v_reward.brand_id is null or not (
    select private.is_brand_member(v_reward.brand_id, array['owner', 'manager'])
  )) then
    raise exception 'Only the reward brand manager or an admin can fulfill this redemption'
      using errcode = '42501';
  end if;
  if v_redemption.status = 'fulfilled' then
    return v_redemption.id;
  end if;
  if v_redemption.status <> 'requested' then
    raise exception 'Redemption cannot be fulfilled in its current status' using errcode = '22023';
  end if;
  update public.redemptions set status = 'fulfilled', fulfilled_at = now()
  where id = v_redemption.id;
  return v_redemption.id;
end;
$$;

create or replace function public.refund_redemption(p_redemption_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_user_id uuid;
  v_reward_id uuid;
  v_redemption public.redemptions%rowtype;
  v_reward public.rewards%rowtype;
begin
  if v_actor_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  select r.user_id, r.reward_id into v_user_id, v_reward_id
  from public.redemptions r where r.id = p_redemption_id;
  if not found then
    raise exception 'Redemption not found' using errcode = '22023';
  end if;

  -- Keep the lock order consistent with redeem_reward: wallet, reward, redemption.
  perform 1 from public.profiles where id = v_user_id for update;
  select * into v_reward from public.rewards where id = v_reward_id for update;
  select * into v_redemption from public.redemptions where id = p_redemption_id for update;
  if not (select private.is_admin()) and (v_reward.brand_id is null or not (
    select private.is_brand_member(v_reward.brand_id, array['owner', 'manager'])
  )) then
    raise exception 'Only the reward brand manager or an admin can refund this redemption'
      using errcode = '42501';
  end if;
  if v_redemption.status = 'refunded' then
    return v_redemption.id;
  end if;
  if v_redemption.status not in ('requested', 'fulfilled') then
    raise exception 'Redemption cannot be refunded in its current status' using errcode = '22023';
  end if;

  update public.redemptions set status = 'refunded', fulfilled_at = null
  where id = v_redemption.id;
  if v_reward.stock is not null then
    update public.rewards set stock = stock + 1 where id = v_reward.id;
  end if;
  insert into public.point_transactions
    (user_id, actor_id, amount, transaction_type, source, reference_id, redemption_id, description)
  values
    (v_user_id, v_actor_id, v_redemption.points_spent, 'refund', 'redemption',
      v_redemption.id, v_redemption.id, 'Refund for reward redemption: ' || v_reward.title);
  return v_redemption.id;
end;
$$;

create or replace function public.admin_adjust_points(p_user_id uuid, p_amount bigint, p_description text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_admin_id uuid := (select auth.uid());
  v_transaction_id uuid;
begin
  if v_admin_id is null or not (select private.is_admin()) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_amount = 0 or p_description is null
    or char_length(btrim(p_description)) < 2 or char_length(p_description) > 500 then
    raise exception 'A non-zero amount and a short description are required' using errcode = '22023';
  end if;
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'Profile not found' using errcode = '23503';
  end if;
  insert into public.point_transactions
    (user_id, actor_id, amount, transaction_type, source, description)
  values
    (p_user_id, v_admin_id, p_amount, 'adjustment', 'admin', btrim(p_description))
  returning id into v_transaction_id;
  return v_transaction_id;
end;
$$;

revoke all on function public.join_mission(uuid) from public, anon;
revoke all on function public.join_challenge(uuid) from public, anon;
revoke all on function public.review_activity(uuid, boolean, text) from public, anon;
revoke all on function public.redeem_reward(uuid) from public, anon;
revoke all on function public.fulfill_redemption(uuid) from public, anon;
revoke all on function public.refund_redemption(uuid) from public, anon;
revoke all on function public.admin_adjust_points(uuid, bigint, text) from public, anon;
grant execute on function public.join_mission(uuid) to authenticated;
grant execute on function public.join_challenge(uuid) to authenticated;
grant execute on function public.review_activity(uuid, boolean, text) to authenticated;
grant execute on function public.redeem_reward(uuid) to authenticated;
grant execute on function public.fulfill_redemption(uuid) to authenticated;
grant execute on function public.refund_redemption(uuid) to authenticated;
grant execute on function public.admin_adjust_points(uuid, bigint, text) to authenticated;

create or replace function private.prevent_point_transaction_mutation()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'Point transactions are append-only' using errcode = '55000';
end;
$$;
revoke all on function private.prevent_point_transaction_mutation() from public, anon, authenticated;
create trigger point_transactions_append_only before update or delete on public.point_transactions
  for each row execute function private.prevent_point_transaction_mutation();

commit;
