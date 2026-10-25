begin;

alter table public.missions
 add column recurrence text not null default 'once' check (recurrence in ('once','daily')),
 add column difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
 add column participation_terms text not null default 'ทำกิจกรรมให้ครบเป้าหมายและส่งผลให้ผู้ดูแลตรวจสอบ' check (char_length(btrim(participation_terms)) between 2 and 2000),
 add column allowed_activity_types text[] check (allowed_activity_types is null or (cardinality(allowed_activity_types)>0 and allowed_activity_types <@ array['steps','walk','run','cycle','swim','check_in','custom']::text[])),
 add column seed_key text unique;
grant insert (recurrence,difficulty,participation_terms,allowed_activity_types), update (recurrence,difficulty,participation_terms,allowed_activity_types) on public.missions to authenticated;

create or replace function private.mission_day(p_at timestamptz default now())
returns date language sql stable set search_path='' as $$ select (p_at at time zone 'Asia/Bangkok')::date; $$;
revoke all on function private.mission_day(timestamptz) from public,anon,authenticated;
grant execute on function private.mission_day(timestamptz) to authenticated;

alter table public.user_missions
 add column participation_date date,
 add column mission_snapshot jsonb;
-- Preserve IDs, progress, status and all old once-only participations.
-- Old rows keep a null snapshot and retain the original once-only behavior.
alter table public.user_missions drop constraint user_missions_user_mission_unique;
create unique index user_missions_once_unique on public.user_missions(user_id,mission_id) where participation_date is null;
create unique index user_missions_daily_unique on public.user_missions(user_id,mission_id,participation_date) where participation_date is not null;

create or replace function private.prepare_mission_round()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_mission public.missions%rowtype;
begin
 select * into v_mission from public.missions where id=new.mission_id for share;
 if not found then raise exception 'Mission not found' using errcode='23503'; end if;
 if v_mission.recurrence='daily' then new.participation_date:=coalesce(new.participation_date,private.mission_day());
 elsif new.participation_date is not null then raise exception 'Once-only missions have no daily date' using errcode='22023'; end if;
 new.mission_snapshot:=to_jsonb(v_mission);
 return new;
end $$;
revoke all on function private.prepare_mission_round() from public,anon,authenticated;
create trigger user_missions_prepare_round before insert on public.user_missions for each row execute function private.prepare_mission_round();

create or replace function private.protect_mission_recurrence()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.recurrence<>old.recurrence and exists(select 1 from public.user_missions where mission_id=old.id) then
  raise exception 'Cannot change recurrence of an existing participation' using errcode='22023';
 end if;
 return new;
end $$;
revoke all on function private.protect_mission_recurrence() from public,anon,authenticated;
create trigger missions_protect_recurrence before update on public.missions for each row execute function private.protect_mission_recurrence();

-- Existing ledger rows stay append-only. Future credits carry their round ID.
alter table public.point_transactions add column user_mission_id uuid references public.user_missions(id) on delete restrict;
create unique index point_transactions_one_mission_round_credit on public.point_transactions(user_mission_id)
 where source='mission' and transaction_type='earn' and user_mission_id is not null;
create or replace function private.attach_mission_credit()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_round uuid;
begin
 if new.source='mission' and new.transaction_type='earn' then
  select a.user_mission_id into v_round from public.activities a where a.id=new.activity_id and a.user_id=new.user_id;
  if v_round is null or (new.user_mission_id is not null and new.user_mission_id<>v_round) then raise exception 'Mission credit must reference its own activity round' using errcode='22023'; end if;
  if exists(select 1 from public.point_transactions pt left join public.activities a on a.id=pt.activity_id
   where pt.source='mission' and pt.transaction_type='earn' and (pt.user_mission_id=v_round or a.user_mission_id=v_round)) then
   raise exception 'This mission round has already received points' using errcode='23505';
  end if;
  new.user_mission_id:=v_round;
 end if;
 return new;
end $$;
revoke all on function private.attach_mission_credit() from public,anon,authenticated;
create trigger point_transactions_attach_mission_round before insert on public.point_transactions for each row execute function private.attach_mission_credit();

create or replace function public.join_mission(p_mission_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid:=(select auth.uid()); v_mission public.missions%rowtype; v_day date; v_id uuid;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
 select * into v_mission from public.missions where id=p_mission_id for share;
 if not found or v_mission.status<>'active' or (v_mission.starts_at is not null and v_mission.starts_at>now()) or (v_mission.ends_at is not null and v_mission.ends_at<=now()) then
  raise exception 'Mission is not open for joining' using errcode='22023';
 end if;
 if v_mission.recurrence='daily' then v_day:=private.mission_day(); end if;
 insert into public.user_missions(user_id,mission_id,participation_date) values(v_user,p_mission_id,v_day)
 on conflict do nothing returning id into v_id;
 if v_id is null then select id into v_id from public.user_missions where user_id=v_user and mission_id=p_mission_id and participation_date is not distinct from v_day; end if;
 return v_id;
end $$;
revoke all on function public.join_mission(uuid) from public,anon;
grant execute on function public.join_mission(uuid) to authenticated;

-- Replace the old RPC signature, preserving default arguments for old callers.
drop function public.submit_mission_activity(uuid,numeric,text,text);
create or replace function public.submit_mission_activity(
  p_user_mission_id uuid,
  p_value numeric,
  p_evidence_url text default null,
  p_evidence_notes text default null,
  p_activity_type text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_user_mission public.user_missions%rowtype;
  v_mission public.missions%rowtype;
  v_activity_id uuid;
  v_activity_type text;
  v_evidence_url text := nullif(btrim(p_evidence_url), '');
  v_evidence_notes text := nullif(btrim(p_evidence_notes), '');
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_user_mission_id is null or p_value is null
    or p_value::text in ('NaN', 'Infinity', '-Infinity') or p_value <= 0 then
    raise exception 'A positive finite activity value is required' using errcode = '22023';
  end if;
  if v_evidence_url is not null and (
    char_length(v_evidence_url) > 2048 or v_evidence_url !~* '^https?://'
  ) then
    raise exception 'Evidence URL must be a valid HTTP or HTTPS URL' using errcode = '22023';
  end if;
  if v_evidence_notes is not null and char_length(v_evidence_notes) > 2000 then
    raise exception 'Evidence notes are too long' using errcode = '22023';
  end if;

  select * into v_user_mission
  from public.user_missions
  where id = p_user_mission_id and user_id = v_user_id
  for update;
  if not found then
    raise exception 'Mission participation not found' using errcode = '42501';
  end if;
  if v_user_mission.status not in ('joined', 'in_progress') then
    raise exception 'Mission is no longer accepting activity' using errcode = '22023';
  end if;

  select * into v_mission
  from public.missions
  where id = v_user_mission.mission_id
  for share;
  if not found or v_mission.status <> 'active'
    or (v_mission.starts_at is not null and v_mission.starts_at > now())
    or (v_mission.ends_at is not null and v_mission.ends_at < now()) then
    raise exception 'Mission is not open for activity' using errcode = '22023';
  end if;
  if v_user_mission.participation_date is not null and v_user_mission.participation_date<>private.mission_day() then
    raise exception 'Daily mission round has ended; start today instead' using errcode='22023';
  end if;
  if v_user_mission.mission_snapshot is not null then select * into v_mission from jsonb_populate_record(null::public.missions,v_user_mission.mission_snapshot); end if;
  v_activity_type:=coalesce(p_activity_type,v_mission.activity_type);
  if not (v_activity_type=any(coalesce(v_mission.allowed_activity_types,array[v_mission.activity_type]))) then raise exception 'Activity type is not allowed' using errcode='22023'; end if;
  if round(p_value,3)<>p_value or (v_mission.target_unit in ('steps','sessions','count') and trunc(p_value)<>p_value) then raise exception 'Invalid activity precision' using errcode='22023'; end if;
  if p_value > v_mission.target_value - v_user_mission.progress_value then
    raise exception 'Activity value cannot exceed the remaining mission target' using errcode = '22023';
  end if;
  if v_mission.requires_evidence and v_evidence_url is null and v_evidence_notes is null then
    raise exception 'Evidence is required for this mission' using errcode = '22023';
  end if;

  insert into public.activities (
    user_id, user_mission_id, activity_type, value, unit, evidence_url, evidence_notes
  ) values (
    v_user_id, v_user_mission.id, v_activity_type, p_value,
    v_mission.target_unit, v_evidence_url, v_evidence_notes
  )
  returning id into v_activity_id;

  return v_activity_id;
exception
  when unique_violation then
    raise exception 'A pending submission already exists for this mission'
      using errcode = '23505';
end;
$$;

revoke all on function public.submit_mission_activity(uuid, numeric, text, text, text)
  from public, anon, authenticated;
grant execute on function public.submit_mission_activity(uuid, numeric, text, text, text)
  to authenticated;
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
    if v_user_mission.mission_snapshot is not null then select * into v_mission from jsonb_populate_record(null::public.missions,v_user_mission.mission_snapshot); end if;
    if not (select private.is_admin()) then
      raise exception 'Only an admin can review mission activity' using errcode = '42501';
    end if;
    if p_approved and (not (v_activity.activity_type=any(coalesce(v_mission.allowed_activity_types,array[v_mission.activity_type])))
      or v_activity.unit <> v_mission.target_unit) then
      raise exception 'Activity type or unit does not match the mission' using errcode = '22023';
    end if;
  else
    select * into v_participant from public.challenge_participants
    where id = v_activity.challenge_participant_id for update;
    select * into v_challenge from public.challenges where id = v_participant.challenge_id;
    if not (select private.is_admin()) and not (
      select private.is_active_brand_member(v_challenge.brand_id, array['owner', 'manager'])
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
            v_activity.id, v_activity.id, 'Mission completed: ' || v_mission.title || case when v_user_mission.participation_date is not null then ' [รอบ ' || v_user_mission.participation_date::text || ' Asia/Bangkok]' else '' end)
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

create or replace view public.mission_activity_totals with (security_invoker=true) as
select user_mission_id, sum(value) as reported_value,
 coalesce(sum(value) filter (where verification_status='pending'),0) as pending_value,
 (array_agg(verification_status order by created_at desc,id desc))[1] as last_status
from public.activities where user_mission_id is not null group by user_mission_id;
grant select on public.mission_activity_totals to authenticated;

notify pgrst, 'reload schema';
commit;
