begin;

alter table public.challenges
  add column mission_title text not null default 'ทำกิจกรรมให้ครบเป้าหมาย' check (char_length(btrim(mission_title)) between 2 and 160),
  add column participation_terms text not null default 'ทำกิจกรรมภายในช่วงเวลาที่กำหนด' check (char_length(btrim(participation_terms)) between 2 and 2000),
  add column evidence_instructions text not null default 'ส่งรายละเอียดกิจกรรมหรือ URL หลักฐานให้ผู้จัดตรวจสอบ' check (char_length(btrim(evidence_instructions)) between 2 and 2000),
  add column reward_id uuid references public.rewards(id) on delete restrict;
grant insert (mission_title, participation_terms, evidence_instructions, reward_id),
  update (mission_title, participation_terms, evidence_instructions, reward_id) on public.challenges to authenticated;

create or replace function private.protect_campaign_terms()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_joined boolean; v_terms_changed boolean;
begin
  if tg_op = 'UPDATE' then
    if new.brand_id is distinct from old.brand_id then raise exception 'Campaign ownership cannot change' using errcode='22023'; end if;
    v_terms_changed := row(new.name,new.objective,new.starts_at,new.ends_at,new.budget_amount,new.budget_currency)
      is distinct from row(old.name,old.objective,old.starts_at,old.ends_at,old.budget_amount,old.budget_currency);
    select exists(select 1 from public.challenge_participants cp join public.challenges c on c.id=cp.challenge_id where c.campaign_id=old.id) into v_joined;
    if v_terms_changed and v_joined then raise exception 'Campaign terms are locked after participation' using errcode='22023'; end if;
    if old.status in ('completed','archived') and (v_terms_changed or new.status<>old.status) then raise exception 'Campaign is final' using errcode='22023'; end if;
    if new.status<>old.status and not (
      (new.status='active' and old.status in ('draft','scheduled','paused')) or
      (new.status='paused' and old.status in ('active','scheduled')) or
      (new.status='completed' and old.status in ('active','paused'))
    ) then raise exception 'Invalid campaign status transition' using errcode='22023'; end if;
    if new.status='completed' and old.status<>'completed' and (
      ((new.ends_at is null or new.ends_at>now()) and exists(select 1 from public.challenge_participants cp join public.challenges c on c.id=cp.challenge_id where c.campaign_id=old.id and cp.status in ('joined','in_progress'))) or
      exists(select 1 from public.activities a join public.challenge_participants cp on cp.id=a.challenge_participant_id join public.challenges c on c.id=cp.challenge_id where c.campaign_id=old.id and a.verification_status='pending')
    ) then raise exception 'Finish participant activity and pending reviews before completion' using errcode='22023'; end if;
  end if;
  if exists(select 1 from public.challenges c where c.campaign_id=new.id and ((new.starts_at is not null and c.starts_at is not null and c.starts_at<new.starts_at) or (new.ends_at is not null and c.ends_at is not null and c.ends_at>new.ends_at))) then raise exception 'Campaign dates must contain existing challenges' using errcode='22023'; end if;
  if new.status='active' and new.ends_at is not null and new.ends_at<=now() then raise exception 'Campaign has expired' using errcode='22023'; end if;
  return new;
end $$;
revoke all on function private.protect_campaign_terms() from public,anon,authenticated;
create trigger campaigns_protect_terms before insert or update on public.campaigns for each row execute function private.protect_campaign_terms();

create or replace function private.protect_challenge_terms()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_campaign public.campaigns%rowtype; v_terms_changed boolean;
begin
  -- Same lock order as join_challenge: parent first, then challenge.
  -- An UPDATE already locks its challenge row; parent updates never lock children.
  select * into v_campaign from public.campaigns where id=new.campaign_id for share;
  if not found or v_campaign.brand_id<>new.brand_id then raise exception 'Invalid challenge campaign' using errcode='22023'; end if;
  if tg_op='INSERT' and v_campaign.status in ('completed','archived') then raise exception 'Campaign is final' using errcode='22023'; end if;
  if tg_op='UPDATE' then
    if row(new.brand_id,new.campaign_id) is distinct from row(old.brand_id,old.campaign_id) then raise exception 'Challenge ownership cannot change' using errcode='22023'; end if;
    v_terms_changed := row(new.title,new.description,new.objective,new.mission_title,new.participation_terms,new.evidence_instructions,new.activity_type,new.target_value,new.target_unit,new.reward_points,new.requires_evidence,new.participant_limit,new.starts_at,new.ends_at,new.reward_id)
      is distinct from row(old.title,old.description,old.objective,old.mission_title,old.participation_terms,old.evidence_instructions,old.activity_type,old.target_value,old.target_unit,old.reward_points,old.requires_evidence,old.participant_limit,old.starts_at,old.ends_at,old.reward_id);
    if v_terms_changed and exists(select 1 from public.challenge_participants where challenge_id=old.id) then raise exception 'Challenge terms are locked after participation' using errcode='22023'; end if;
    if old.status in ('completed','cancelled') and (v_terms_changed or new.status<>old.status) then raise exception 'Challenge is final' using errcode='22023'; end if;
    if new.status<>old.status and not (
      (new.status='active' and old.status in ('draft','scheduled','paused')) or
      (new.status='paused' and old.status in ('active','scheduled')) or
      (new.status='completed' and old.status in ('active','paused'))
    ) then raise exception 'Invalid challenge status transition' using errcode='22023'; end if;
    if new.status='completed' and old.status<>'completed' and (
      ((new.ends_at is null or new.ends_at>now()) and exists(select 1 from public.challenge_participants where challenge_id=old.id and status in ('joined','in_progress'))) or
      exists(select 1 from public.activities a join public.challenge_participants cp on cp.id=a.challenge_participant_id where cp.challenge_id=old.id and a.verification_status='pending')
    ) then raise exception 'Finish participant activity and pending reviews before completion' using errcode='22023'; end if;
  end if;
  if new.target_value::text in ('NaN','Infinity','-Infinity') or new.target_value<=0 then raise exception 'Invalid target' using errcode='22023'; end if;
  if not (
    (new.activity_type='steps' and new.target_unit='steps') or
    (new.activity_type in ('walk','run','cycle','swim') and new.target_unit in ('km','miles','minutes')) or
    (new.activity_type='check_in' and new.target_unit in ('count','sessions')) or
    (new.activity_type='custom')
  ) then raise exception 'Activity and unit do not match' using errcode='22023'; end if;
  if new.target_unit in ('steps','count','sessions') and trunc(new.target_value)<>new.target_value then raise exception 'This target must be a whole number' using errcode='22023'; end if;
  if new.reward_id is not null and not exists(select 1 from public.rewards where id=new.reward_id and brand_id=new.brand_id) then raise exception 'Reward must belong to this brand' using errcode='22023'; end if;
  if (v_campaign.starts_at is not null and new.starts_at is not null and new.starts_at<v_campaign.starts_at)
    or (v_campaign.ends_at is not null and new.ends_at is not null and new.ends_at>v_campaign.ends_at) then raise exception 'Challenge dates must fit the campaign' using errcode='22023'; end if;
  if new.status='active' and (v_campaign.status<>'active' or (new.ends_at is not null and new.ends_at<=now())) then raise exception 'Activate the parent campaign first and check dates' using errcode='22023'; end if;
  return new;
end $$;
revoke all on function private.protect_challenge_terms() from public,anon,authenticated;
create trigger challenges_protect_terms before insert or update on public.challenges for each row execute function private.protect_challenge_terms();

-- Serialize parent changes with joins, and serialize the last seat on challenge.
create or replace function public.join_challenge(p_challenge_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid()); v_campaign_id uuid;
  v_campaign public.campaigns%rowtype; v_challenge public.challenges%rowtype; v_id uuid;
begin
  if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select campaign_id into v_campaign_id from public.challenges where id=p_challenge_id;
  select * into v_campaign from public.campaigns where id=v_campaign_id for share;
  select * into v_challenge from public.challenges where id=p_challenge_id for update;
  if not found then raise exception 'Challenge not found' using errcode='22023'; end if;
  -- A retry returns the existing participation, including while new joins are paused.
  select id into v_id from public.challenge_participants where challenge_id=p_challenge_id and user_id=v_user;
  if v_id is not null then return v_id; end if;
  if v_challenge.status<>'active' or v_campaign.status<>'active'
    or not exists(select 1 from public.brands where id=v_challenge.brand_id and status='active')
    or (v_challenge.starts_at is not null and v_challenge.starts_at>now()) or (v_challenge.ends_at is not null and v_challenge.ends_at<=now())
    or (v_campaign.starts_at is not null and v_campaign.starts_at>now()) or (v_campaign.ends_at is not null and v_campaign.ends_at<=now()) then raise exception 'Challenge is not open for joining' using errcode='22023'; end if;
  if v_challenge.participant_limit is not null and (select count(*) from public.challenge_participants where challenge_id=p_challenge_id)>=v_challenge.participant_limit then raise exception 'Challenge has reached its participant limit' using errcode='22023'; end if;
  insert into public.challenge_participants(challenge_id,user_id) values(p_challenge_id,v_user) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.join_challenge(uuid) from public,anon;
grant execute on function public.join_challenge(uuid) to authenticated;

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
  if not found or v_challenge.status not in ('active','paused')
    or (v_challenge.starts_at is not null and v_challenge.starts_at > now())
    or (v_challenge.ends_at is not null and v_challenge.ends_at < now()) then
    raise exception 'Challenge is not open for activity' using errcode = '22023';
  end if;
  if not exists (select 1 from public.campaigns c join public.brands b on b.id=c.brand_id
    where c.id=v_challenge.campaign_id and c.status in ('active','paused') and b.status='active'
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

create or replace function private.is_challenge_participant(p_challenge_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.challenge_participants where challenge_id=p_challenge_id and user_id=(select auth.uid()));
$$;
revoke all on function private.is_challenge_participant(uuid) from public,anon,authenticated;
grant execute on function private.is_challenge_participant(uuid) to anon,authenticated;
create policy challenges_select_participating on public.challenges for select to authenticated
 using ((select private.is_challenge_participant(id)));

notify pgrst, 'reload schema';

commit;
