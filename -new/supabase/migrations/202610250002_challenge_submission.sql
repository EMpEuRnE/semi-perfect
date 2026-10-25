begin;
create unique index activities_one_pending_challenge_idx on public.activities(challenge_participant_id) where challenge_participant_id is not null and verification_status='pending';
create or replace function public.submit_challenge_activity(
  p_participant_id uuid,
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
  v_participant public.challenge_participants%rowtype;
  v_challenge public.challenges%rowtype;
  v_activity_id uuid;
  v_evidence_url text := nullif(btrim(p_evidence_url), '');
  v_evidence_notes text := nullif(btrim(p_evidence_notes), '');
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_participant_id is null or p_value is null
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

  select * into v_participant
  from public.challenge_participants
  where id = p_participant_id and user_id = v_user_id
  for update;
  if not found then
    raise exception 'Challenge participation not found' using errcode = '42501';
  end if;
  if v_participant.status not in ('joined', 'in_progress') then
    raise exception 'Challenge is no longer accepting activity' using errcode = '22023';
  end if;

  select * into v_challenge
  from public.challenges
  where id = v_participant.challenge_id
  for share;
  if not found or v_challenge.status <> 'active'
    or (v_challenge.starts_at is not null and v_challenge.starts_at > now())
    or (v_challenge.ends_at is not null and v_challenge.ends_at < now()) then
    raise exception 'Challenge is not open for activity' using errcode = '22023';
  end if;
  if not exists (select 1 from public.campaigns c join public.brands b on b.id=c.brand_id
    where c.id=v_challenge.campaign_id and c.status='active' and b.status='active'
    and (c.starts_at is null or c.starts_at <= now()) and (c.ends_at is null or c.ends_at >= now())) then
    raise exception 'Campaign is not open' using errcode='22023';
  end if;
  if p_value > v_challenge.target_value - v_participant.progress_value then
    raise exception 'Activity value cannot exceed the remaining challenge target' using errcode = '22023';
  end if;
  if v_challenge.requires_evidence and v_evidence_url is null and v_evidence_notes is null then
    raise exception 'Evidence is required for this challenge' using errcode = '22023';
  end if;

  insert into public.activities (
    user_id, challenge_participant_id, activity_type, value, unit, evidence_url, evidence_notes
  ) values (
    v_user_id, v_participant.id, v_challenge.activity_type, p_value,
    v_challenge.target_unit, v_evidence_url, v_evidence_notes
  )
  returning id into v_activity_id;

  return v_activity_id;
exception
  when unique_violation then
    raise exception 'A pending subchallenge already exists for this challenge'
      using errcode = '23505';
end;
$$;

revoke all on function public.submit_challenge_activity(uuid, numeric, text, text)
  from public, anon, authenticated;
grant execute on function public.submit_challenge_activity(uuid, numeric, text, text)
  to authenticated;
comment on function public.submit_challenge_activity(uuid, numeric, text, text) is
  'Creates an owner-bound pending challenge activity; points are issued only by trusted review_activity.';

commit;
