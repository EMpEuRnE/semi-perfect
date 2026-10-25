begin;

-- Keep the browser from inserting activity rows directly. Submissions go through
-- the authenticated, server-validated RPC below and can only start as pending.
drop policy if exists activities_insert_own_pending on public.activities;
revoke insert on public.activities from authenticated;

-- One review in flight per mission participation prevents double-clicks and
-- concurrent duplicate submissions while still allowing later progress entries.
create unique index activities_one_pending_mission_submission_idx
  on public.activities (user_mission_id)
  where user_mission_id is not null and verification_status = 'pending';

-- Participants can still read a mission in their history after it is archived.
create policy missions_select_participating on public.missions for select to authenticated
  using (exists (
    select 1 from public.user_missions um
    where um.mission_id = missions.id and um.user_id = (select auth.uid())
  ));

create or replace function public.submit_mission_activity(
  p_user_mission_id uuid,
  p_value numeric,
  p_evidence_url text default null,
  p_evidence_notes text default null
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
  if p_value > v_mission.target_value - v_user_mission.progress_value then
    raise exception 'Activity value cannot exceed the remaining mission target' using errcode = '22023';
  end if;
  if v_mission.requires_evidence and v_evidence_url is null and v_evidence_notes is null then
    raise exception 'Evidence is required for this mission' using errcode = '22023';
  end if;

  insert into public.activities (
    user_id, user_mission_id, activity_type, value, unit, evidence_url, evidence_notes
  ) values (
    v_user_id, v_user_mission.id, v_mission.activity_type, p_value,
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

revoke all on function public.submit_mission_activity(uuid, numeric, text, text)
  from public, anon, authenticated;
grant execute on function public.submit_mission_activity(uuid, numeric, text, text)
  to authenticated;
comment on function public.submit_mission_activity(uuid, numeric, text, text) is
  'Creates an owner-bound pending mission activity; points are issued only by trusted review_activity.';

commit;
