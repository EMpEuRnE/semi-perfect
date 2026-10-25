-- Move & Earn: fresh database installation only.
-- Run in Supabase SQL Editor as the project owner.
-- Does not insert passwordless demo auth users or touch existing tables.
-- Existing installs: use the individual pending migrations instead.
begin;
do $$ begin
 if exists(select 1 from information_schema.tables where table_schema='public' and table_name in ('profiles','brands','brand_memberships','missions','campaigns','challenges','rewards','redemptions','point_transactions','activities','user_missions','challenge_participants')) then
  raise exception 'Existing Move & Earn tables detected. Stop and compare migration history; no reset was performed.';
 end if;
end $$;

-- 202610240001_core_entities.sql
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text check (display_name is null or char_length(display_name) <= 80),
  avatar_url text,
  role text not null default 'user'
    check (role in ('user', 'brand', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.brands (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text,
  logo_url text,
  status text not null default 'pending'
    check (status in ('pending', 'active', 'suspended')),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.brand_memberships (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.brands (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete restrict,
  membership_role text not null default 'member'
    check (membership_role in ('owner', 'manager', 'analyst', 'member')),
  status text not null default 'active'
    check (status in ('invited', 'active', 'suspended')),
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint brand_memberships_brand_profile_unique unique (brand_id, profile_id)
);

create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.brands (id) on delete restrict,
  name text not null check (char_length(btrim(name)) between 2 and 160),
  objective text not null check (char_length(btrim(objective)) between 2 and 2000),
  budget_amount numeric(14, 2) check (budget_amount is null or budget_amount >= 0),
  budget_currency char(3) not null default 'THB'
    check (budget_currency ~ '^[A-Z]{3}$'),
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'active', 'paused', 'completed', 'archived')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint campaigns_dates_valid check (starts_at is null or ends_at is null or starts_at < ends_at),
  constraint campaigns_id_brand_unique unique (id, brand_id)
);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 2 and 160),
  description text not null check (char_length(btrim(description)) between 2 and 4000),
  mission_type text not null
    check (mission_type in ('steps', 'distance', 'duration', 'check_in', 'custom')),
  activity_type text not null
    check (activity_type in ('steps', 'walk', 'run', 'cycle', 'swim', 'check_in', 'custom')),
  target_value numeric(14, 3) not null check (target_value > 0),
  target_unit text not null
    check (target_unit in ('steps', 'km', 'miles', 'minutes', 'sessions', 'count')),
  points integer not null check (points > 0),
  requires_evidence boolean not null default false,
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'active', 'paused', 'ended', 'archived')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint missions_dates_valid check (starts_at is null or ends_at is null or starts_at < ends_at)
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null,
  brand_id uuid not null,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  description text not null check (char_length(btrim(description)) between 2 and 4000),
  objective text not null check (char_length(btrim(objective)) between 2 and 2000),
  activity_type text not null
    check (activity_type in ('steps', 'walk', 'run', 'cycle', 'swim', 'check_in', 'custom')),
  target_value numeric(14, 3) not null check (target_value > 0),
  target_unit text not null
    check (target_unit in ('steps', 'km', 'miles', 'minutes', 'sessions', 'count')),
  reward_points integer not null check (reward_points > 0),
  requires_evidence boolean not null default false,
  participant_limit integer check (participant_limit is null or participant_limit > 0),
  status text not null default 'draft'
    check (status in ('draft', 'scheduled', 'active', 'paused', 'completed', 'cancelled')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenges_dates_valid check (starts_at is null or ends_at is null or starts_at < ends_at),
  constraint challenges_campaign_brand_fk
    foreign key (campaign_id, brand_id)
    references public.campaigns (id, brand_id)
    on delete restrict
);

create index brands_status_idx on public.brands (status);
create index brand_memberships_profile_status_idx on public.brand_memberships (profile_id, status);
create index campaigns_brand_status_created_idx
  on public.campaigns (brand_id, status, created_at desc);
create index missions_status_dates_idx on public.missions (status, starts_at, ends_at);
create index challenges_campaign_status_idx on public.challenges (campaign_id, status);
create index challenges_brand_status_dates_idx on public.challenges (brand_id, status, starts_at, ends_at);

-- 202610240002_participation_rewards_ledger.sql
create table public.user_missions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  mission_id uuid not null references public.missions (id) on delete restrict,
  status text not null default 'joined'
    check (status in ('joined', 'in_progress', 'completed', 'cancelled', 'expired')),
  progress_value numeric(14, 3) not null default 0 check (progress_value >= 0),
  joined_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_missions_user_mission_unique unique (user_id, mission_id),
  constraint user_missions_id_user_unique unique (id, user_id),
  constraint user_missions_completion_consistent check (
    (status = 'completed') = (completed_at is not null)
  )
);

create table public.challenge_participants (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  status text not null default 'joined'
    check (status in ('joined', 'in_progress', 'completed', 'cancelled', 'disqualified')),
  progress_value numeric(14, 3) not null default 0 check (progress_value >= 0),
  joined_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint challenge_participants_challenge_user_unique unique (challenge_id, user_id),
  constraint challenge_participants_id_user_unique unique (id, user_id),
  constraint challenge_participants_completion_consistent check (
    (status = 'completed') = (completed_at is not null)
  )
);

create table public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  user_mission_id uuid,
  challenge_participant_id uuid,
  activity_type text not null
    check (activity_type in ('steps', 'walk', 'run', 'cycle', 'swim', 'check_in', 'custom')),
  value numeric(14, 3) not null check (value > 0),
  unit text not null check (unit in ('steps', 'km', 'miles', 'minutes', 'sessions', 'count')),
  evidence_url text,
  evidence_notes text check (evidence_notes is null or char_length(evidence_notes) <= 2000),
  verification_status text not null default 'pending'
    check (verification_status in ('pending', 'approved', 'rejected')),
  reviewer_note text check (reviewer_note is null or char_length(reviewer_note) <= 1000),
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint activities_exactly_one_participation check (
    (user_mission_id is not null and challenge_participant_id is null)
    or (user_mission_id is null and challenge_participant_id is not null)
  ),
  constraint activities_review_consistent check (
    (verification_status = 'pending' and reviewed_by is null and reviewed_at is null)
    or (verification_status <> 'pending' and reviewed_at is not null)
  ),
  constraint activities_mission_user_fk
    foreign key (user_mission_id, user_id)
    references public.user_missions (id, user_id) on delete restrict,
  constraint activities_challenge_participant_user_fk
    foreign key (challenge_participant_id, user_id)
    references public.challenge_participants (id, user_id) on delete restrict
);

create table public.rewards (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references public.brands (id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 2 and 160),
  description text not null check (char_length(btrim(description)) between 2 and 4000),
  image_url text,
  category text not null check (char_length(btrim(category)) between 2 and 80),
  points_required integer not null check (points_required > 0),
  stock integer check (stock is null or stock >= 0),
  status text not null default 'draft'
    check (status in ('draft', 'active', 'paused', 'out_of_stock', 'expired', 'archived')),
  expires_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  reward_id uuid not null references public.rewards (id) on delete restrict,
  points_spent integer not null check (points_spent > 0),
  status text not null default 'requested'
    check (status in ('requested', 'fulfilled', 'cancelled', 'refunded')),
  redemption_code text,
  fulfilled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint redemptions_id_user_unique unique (id, user_id),
  constraint redemptions_fulfillment_consistent check (
    (status = 'fulfilled') = (fulfilled_at is not null)
  )
);

create table public.point_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete restrict,
  actor_id uuid references public.profiles (id) on delete set null,
  amount bigint not null check (amount <> 0),
  transaction_type text not null
    check (transaction_type in ('earn', 'spend', 'adjustment', 'refund')),
  source text not null
    check (source in ('mission', 'challenge', 'redemption', 'admin', 'system')),
  reference_id uuid,
  activity_id uuid references public.activities (id) on delete restrict,
  redemption_id uuid references public.redemptions (id) on delete restrict,
  description text not null check (char_length(btrim(description)) between 2 and 500),
  created_at timestamptz not null default now(),
  constraint point_transactions_source_reference_check check (
    (source in ('mission', 'challenge') and transaction_type = 'earn'
      and amount > 0 and activity_id is not null and redemption_id is null
      and reference_id = activity_id)
    or (source = 'redemption' and transaction_type = 'spend'
      and amount < 0 and activity_id is null and redemption_id is not null
      and reference_id = redemption_id)
    or (source = 'redemption' and transaction_type = 'refund'
      and amount > 0 and activity_id is null and redemption_id is not null
      and reference_id = redemption_id)
    or (source in ('admin', 'system') and transaction_type = 'adjustment'
      and activity_id is null and redemption_id is null and reference_id is null)
  )
);

create unique index point_transactions_activity_once_idx
  on public.point_transactions (activity_id) where activity_id is not null;
create unique index point_transactions_redemption_spend_once_idx
  on public.point_transactions (redemption_id)
  where source = 'redemption' and transaction_type = 'spend';
create unique index point_transactions_redemption_refund_once_idx
  on public.point_transactions (redemption_id)
  where source = 'redemption' and transaction_type = 'refund';
create unique index redemptions_code_unique_idx
  on public.redemptions (redemption_code) where redemption_code is not null;

create index user_missions_mission_status_idx on public.user_missions (mission_id, status);
create index user_missions_user_status_idx on public.user_missions (user_id, status, updated_at desc);
create index challenge_participants_challenge_status_idx
  on public.challenge_participants (challenge_id, status);
create index challenge_participants_user_status_idx
  on public.challenge_participants (user_id, status, updated_at desc);
create index activities_user_created_idx on public.activities (user_id, created_at desc);
create index activities_pending_created_idx on public.activities (created_at)
  where verification_status = 'pending';
create index activities_mission_created_idx on public.activities (user_mission_id, created_at desc)
  where user_mission_id is not null;
create index activities_challenge_created_idx
  on public.activities (challenge_participant_id, created_at desc)
  where challenge_participant_id is not null;
create index rewards_status_category_idx on public.rewards (status, category);
create index rewards_brand_status_idx on public.rewards (brand_id, status) where brand_id is not null;
create index redemptions_user_created_idx on public.redemptions (user_id, created_at desc);
create index redemptions_reward_status_idx on public.redemptions (reward_id, status, created_at desc);
create index point_transactions_user_created_idx
  on public.point_transactions (user_id, created_at desc);
create index point_transactions_source_created_idx
  on public.point_transactions (source, created_at desc);

-- 202610240003_authorization_and_policies.sql
alter table public.brands alter column created_by set default auth.uid();
alter table public.campaigns alter column created_by set default auth.uid();
alter table public.missions alter column created_by set default auth.uid();
alter table public.challenges alter column created_by set default auth.uid();
alter table public.rewards alter column created_by set default auth.uid();

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  );
$$;

create or replace function private.is_brand_member(p_brand_id uuid, p_roles text[] default null)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.brand_memberships bm
    where bm.brand_id = p_brand_id
      and bm.profile_id = (select auth.uid())
      and bm.status = 'active'
      and (p_roles is null or bm.membership_role = any (p_roles))
  );
$$;

create or replace function private.is_active_brand_member(p_brand_id uuid, p_roles text[] default null)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.brand_memberships bm
    join public.brands b on b.id = bm.brand_id
    where bm.brand_id = p_brand_id
      and bm.profile_id = (select auth.uid())
      and bm.status = 'active' and b.status = 'active'
      and (p_roles is null or bm.membership_role = any (p_roles))
  );
$$;

revoke all on function private.is_admin() from public, anon, authenticated;
revoke all on function private.is_brand_member(uuid, text[]) from public, anon, authenticated;
revoke all on function private.is_active_brand_member(uuid, text[]) from public, anon, authenticated;
grant execute on function private.is_admin() to anon, authenticated;
grant execute on function private.is_brand_member(uuid, text[]) to anon, authenticated;
grant execute on function private.is_active_brand_member(uuid, text[]) to authenticated;

create or replace function private.touch_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.touch_updated_at() from public, anon, authenticated;

create trigger profiles_touch_updated_at before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger brands_touch_updated_at before update on public.brands
  for each row execute function private.touch_updated_at();
create trigger brand_memberships_touch_updated_at before update on public.brand_memberships
  for each row execute function private.touch_updated_at();
create trigger campaigns_touch_updated_at before update on public.campaigns
  for each row execute function private.touch_updated_at();
create trigger missions_touch_updated_at before update on public.missions
  for each row execute function private.touch_updated_at();
create trigger challenges_touch_updated_at before update on public.challenges
  for each row execute function private.touch_updated_at();
create trigger user_missions_touch_updated_at before update on public.user_missions
  for each row execute function private.touch_updated_at();
create trigger challenge_participants_touch_updated_at before update on public.challenge_participants
  for each row execute function private.touch_updated_at();
create trigger rewards_touch_updated_at before update on public.rewards
  for each row execute function private.touch_updated_at();
create trigger redemptions_touch_updated_at before update on public.redemptions
  for each row execute function private.touch_updated_at();

create or replace function private.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_display_name text;
  v_avatar_url text;
begin
  v_display_name := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')), '');
  v_avatar_url := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'avatar_url', '')), '');
  insert into public.profiles (id, display_name, avatar_url)
  values (new.id, left(v_display_name, 80), v_avatar_url)
  on conflict (id) do nothing;
  -- Never copy the user-controlled role field from Auth metadata.
  return new;
end;
$$;
revoke all on function private.handle_new_auth_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_auth_user();

insert into public.profiles (id, display_name, avatar_url)
select u.id,
  left(nullif(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), ''), 80),
  nullif(btrim(coalesce(u.raw_user_meta_data ->> 'avatar_url', '')), '')
from auth.users u
on conflict (id) do nothing;

alter table public.profiles enable row level security;
alter table public.brands enable row level security;
alter table public.brand_memberships enable row level security;
alter table public.campaigns enable row level security;
alter table public.missions enable row level security;
alter table public.challenges enable row level security;
alter table public.user_missions enable row level security;
alter table public.activities enable row level security;
alter table public.challenge_participants enable row level security;
alter table public.point_transactions enable row level security;
alter table public.rewards enable row level security;
alter table public.redemptions enable row level security;

revoke all on public.profiles, public.brands, public.brand_memberships,
  public.campaigns, public.missions, public.challenges, public.user_missions,
  public.activities, public.challenge_participants, public.point_transactions,
  public.rewards, public.redemptions from anon, authenticated;

grant select on public.profiles to authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;
grant select on public.brands, public.campaigns, public.missions,
  public.challenges, public.rewards to anon, authenticated;
grant update (name, slug, description, logo_url) on public.brands to authenticated;
grant select on public.brand_memberships to authenticated;

grant insert (brand_id, name, objective, budget_amount, budget_currency, starts_at, ends_at)
  on public.campaigns to authenticated;
grant update (name, objective, budget_amount, budget_currency, status, starts_at, ends_at)
  on public.campaigns to authenticated;
grant insert (title, description, mission_type, activity_type, target_value, target_unit,
  points, requires_evidence, status, starts_at, ends_at) on public.missions to authenticated;
grant update (title, description, mission_type, activity_type, target_value, target_unit,
  points, requires_evidence, status, starts_at, ends_at) on public.missions to authenticated;
grant insert (campaign_id, brand_id, title, description, objective, activity_type,
  target_value, target_unit, reward_points, requires_evidence, participant_limit, starts_at, ends_at)
  on public.challenges to authenticated;
grant update (title, description, objective, activity_type, target_value, target_unit,
  reward_points, requires_evidence, participant_limit, status, starts_at, ends_at)
  on public.challenges to authenticated;
grant select on public.user_missions, public.challenge_participants to authenticated;
grant select on public.activities to authenticated;
grant insert (user_id, user_mission_id, challenge_participant_id, activity_type,
  value, unit, evidence_url, evidence_notes) on public.activities to authenticated;
grant select on public.point_transactions to authenticated;
grant insert (brand_id, title, description, image_url, category, points_required, stock, expires_at)
  on public.rewards to authenticated;
grant update (title, description, image_url, category, points_required, stock, status, expires_at)
  on public.rewards to authenticated;
grant select on public.redemptions to authenticated;

create policy profiles_select_self_or_admin on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy brands_select_public_or_member on public.brands for select to anon, authenticated
  using (status = 'active' or (select private.is_brand_member(id)) or (select private.is_admin()));
create policy brands_update_manager on public.brands for update to authenticated
  using ((select private.is_active_brand_member(id, array['owner', 'manager'])) or (select private.is_admin()))
  with check ((select private.is_active_brand_member(id, array['owner', 'manager'])) or (select private.is_admin()));

create policy memberships_select_self_brand_admin on public.brand_memberships for select to authenticated
  using (profile_id = (select auth.uid())
    or (select private.is_brand_member(brand_id, array['owner', 'manager', 'analyst']))
    or (select private.is_admin()));

create policy campaigns_select_discovery_or_brand on public.campaigns for select to anon, authenticated
  using ((status in ('scheduled', 'active')
      and (starts_at is null or starts_at <= now())
      and (ends_at is null or ends_at >= now())
      and exists (select 1 from public.brands b where b.id = campaigns.brand_id and b.status = 'active'))
    or (select private.is_brand_member(brand_id)) or (select private.is_admin()));
create policy campaigns_insert_brand_manager on public.campaigns for insert to authenticated
  with check ((select private.is_active_brand_member(brand_id, array['owner', 'manager']))
    and (created_by is null or created_by = (select auth.uid())));
create policy campaigns_update_brand_manager on public.campaigns for update to authenticated
  using ((select private.is_active_brand_member(brand_id, array['owner', 'manager'])) or (select private.is_admin()))
  with check ((select private.is_active_brand_member(brand_id, array['owner', 'manager'])) or (select private.is_admin()));

create policy missions_select_discovery on public.missions for select to anon, authenticated
  using ((status in ('scheduled', 'active')
      and (starts_at is null or starts_at <= now())
      and (ends_at is null or ends_at >= now()))
    or (select private.is_admin()));
create policy missions_admin_insert on public.missions for insert to authenticated
  with check ((select private.is_admin()) and (created_by is null or created_by = (select auth.uid())));
create policy missions_admin_update on public.missions for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));

create policy challenges_select_discovery_or_brand on public.challenges for select to anon, authenticated
  using ((status in ('scheduled', 'active')
      and (starts_at is null or starts_at <= now())
      and (ends_at is null or ends_at >= now())
      and exists (select 1 from public.campaigns cam
        join public.brands b on b.id = cam.brand_id
        where cam.id = challenges.campaign_id and cam.brand_id = challenges.brand_id
          and cam.status in ('scheduled', 'active')
          and (cam.starts_at is null or cam.starts_at <= now())
          and (cam.ends_at is null or cam.ends_at >= now())
          and b.status = 'active'))
    or (select private.is_brand_member(brand_id)) or (select private.is_admin()));
create policy challenges_insert_brand_manager on public.challenges for insert to authenticated
  with check ((select private.is_active_brand_member(brand_id, array['owner', 'manager']))
    and (created_by is null or created_by = (select auth.uid()))
    and exists (select 1 from public.campaigns c
      where c.id = campaign_id and c.brand_id = challenges.brand_id
        and c.status in ('draft', 'scheduled', 'active', 'paused')));
create policy challenges_update_brand_manager on public.challenges for update to authenticated
  using ((select private.is_active_brand_member(brand_id, array['owner', 'manager'])) or (select private.is_admin()))
  with check ((select private.is_active_brand_member(brand_id, array['owner', 'manager'])) or (select private.is_admin()));

create policy user_missions_select_self_or_admin on public.user_missions for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy participants_select_self_brand_or_admin on public.challenge_participants for select to authenticated
  using (user_id = (select auth.uid())
    or exists (select 1 from public.challenges c
      where c.id = challenge_participants.challenge_id
        and (select private.is_brand_member(c.brand_id, array['owner', 'manager', 'analyst'])))
    or (select private.is_admin()));

create policy activities_select_self_reviewer_or_admin on public.activities for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin())
    or exists (select 1 from public.challenge_participants cp
      join public.challenges c on c.id = cp.challenge_id
      where cp.id = activities.challenge_participant_id
        and (select private.is_brand_member(c.brand_id, array['owner', 'manager']))));
create policy activities_insert_own_pending on public.activities for insert to authenticated
  with check (user_id = (select auth.uid()) and verification_status = 'pending'
    and reviewed_by is null and reviewed_at is null
    and (
      exists (select 1 from public.user_missions um
        join public.missions m on m.id = um.mission_id
        where um.id = user_mission_id and um.user_id = activities.user_id
          and um.status in ('joined', 'in_progress') and m.status = 'active'
          and (m.starts_at is null or m.starts_at <= now())
          and (m.ends_at is null or m.ends_at >= now()))
      or exists (select 1 from public.challenge_participants cp
        join public.challenges c on c.id = cp.challenge_id
        join public.campaigns cam on cam.id = c.campaign_id and cam.brand_id = c.brand_id
        where cp.id = challenge_participant_id and cp.user_id = activities.user_id
          and cp.status in ('joined', 'in_progress') and c.status = 'active' and cam.status = 'active'
          and (c.starts_at is null or c.starts_at <= now())
          and (c.ends_at is null or c.ends_at >= now())
          and (cam.starts_at is null or cam.starts_at <= now())
          and (cam.ends_at is null or cam.ends_at >= now()))
    ));

create policy transactions_select_owner_brand_or_admin on public.point_transactions for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin())
    or exists (select 1 from public.activities a
      join public.challenge_participants cp on cp.id = a.challenge_participant_id
      join public.challenges c on c.id = cp.challenge_id
      where a.id = point_transactions.activity_id
        and (select private.is_brand_member(c.brand_id, array['owner', 'manager', 'analyst']))));

create policy rewards_select_active_or_brand on public.rewards for select to anon, authenticated
  using ((status = 'active' and (expires_at is null or expires_at > now())
      and (brand_id is null or exists (select 1 from public.brands b
        where b.id = rewards.brand_id and b.status = 'active')))
    or (brand_id is not null and (select private.is_brand_member(brand_id)))
    or (select private.is_admin()));
create policy rewards_insert_brand_manager on public.rewards for insert to authenticated
  with check (brand_id is not null
    and (select private.is_active_brand_member(brand_id, array['owner', 'manager']))
    and (created_by is null or created_by = (select auth.uid())));
create policy rewards_update_brand_manager on public.rewards for update to authenticated
  using ((brand_id is not null and (select private.is_active_brand_member(brand_id, array['owner', 'manager'])))
    or (select private.is_admin()))
  with check ((brand_id is not null and (select private.is_active_brand_member(brand_id, array['owner', 'manager'])))
    or (select private.is_admin()));

create policy redemptions_select_owner_brand_or_admin on public.redemptions for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_admin())
    or exists (select 1 from public.rewards r
      where r.id = redemptions.reward_id and r.brand_id is not null
        and (select private.is_brand_member(r.brand_id, array['owner', 'manager', 'analyst']))));

-- 202610240004_secure_workflows.sql
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

-- 202610240005_reporting_views.sql
create or replace view public.user_point_balances
with (security_invoker = true)
as
select p.id as user_id, coalesce(sum(pt.amount), 0)::bigint as balance
from public.profiles p
left join public.point_transactions pt on pt.user_id = p.id
group by p.id;
grant select on public.user_point_balances to authenticated;

-- This aggregate view runs with its owner privileges so analysts can see totals
-- without being granted access to individual activity evidence. The membership
-- predicate below is the required tenant boundary; only authenticated can query it.
create or replace view public.campaign_results
with (security_invoker = false, security_barrier = true)
as
select
  cam.id as campaign_id,
  cam.brand_id,
  cam.name as campaign_name,
  cam.status,
  (select count(*) from public.challenges c where c.campaign_id = cam.id) as challenge_count,
  (select count(*) from public.challenge_participants cp
    join public.challenges c on c.id = cp.challenge_id where c.campaign_id = cam.id) as participant_count,
  (select count(*) from public.challenge_participants cp
    join public.challenges c on c.id = cp.challenge_id
    where c.campaign_id = cam.id and cp.status = 'completed') as completion_count,
  (select count(*) from public.activities a
    join public.challenge_participants cp on cp.id = a.challenge_participant_id
    join public.challenges c on c.id = cp.challenge_id where c.campaign_id = cam.id) as activity_count,
  (select coalesce(sum(pt.amount), 0)::bigint from public.point_transactions pt
    join public.activities a on a.id = pt.activity_id
    join public.challenge_participants cp on cp.id = a.challenge_participant_id
    join public.challenges c on c.id = cp.challenge_id
    where c.campaign_id = cam.id and pt.transaction_type = 'earn') as points_awarded
from public.campaigns cam
where (select private.is_brand_member(cam.brand_id, array['owner', 'manager', 'analyst']))
  or (select private.is_admin());
grant select on public.campaign_results to authenticated;

-- 202610250001_user_mission_activity_workflow.sql
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

-- 202610250002_challenge_submission.sql
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

-- 202610250003_active_brand_review.sql
-- Suspended brands cannot review activities, fulfill or refund rewards.
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
    select private.is_active_brand_member(v_reward.brand_id, array['owner', 'manager'])
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
    select private.is_active_brand_member(v_reward.brand_id, array['owner', 'manager'])
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

-- 202610250004_idempotent_redemption.sql
-- Keep applied migrations intact. Historical redemptions retain a null request ID.
alter table public.redemptions add column request_id uuid;
create unique index redemptions_user_request_unique_idx
  on public.redemptions(user_id, request_id) where request_id is not null;
-- Replace rather than overload the one-argument function to avoid RPC ambiguity.
drop function public.redeem_reward(uuid);

create or replace function public.redeem_reward(p_reward_id uuid, p_request_id uuid default gen_random_uuid())
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

  if p_request_id is null then
    raise exception 'Request ID is required' using errcode = '22023';
  end if;

  -- The profile row acts as a per-user wallet lock while balance is checked and debited.
  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    raise exception 'Profile not found' using errcode = '23503';
  end if;
  select id, reward_id into v_redemption_id, v_reward.id
  from public.redemptions where user_id = v_user_id and request_id = p_request_id;
  if found then
    if v_reward.id <> p_reward_id then
      raise exception 'Request ID already used for another reward' using errcode = '22023';
    end if;
    return v_redemption_id;
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
  insert into public.redemptions (user_id, reward_id, points_spent, redemption_code, request_id)
  values (v_user_id, v_reward.id, v_reward.points_required, v_code, p_request_id)
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

revoke all on function public.redeem_reward(uuid, uuid) from public, anon;
grant execute on function public.redeem_reward(uuid, uuid) to authenticated;

-- 202610250005_nonnegative_adjustments.sql
create or replace function public.admin_adjust_points(p_user_id uuid, p_amount bigint, p_description text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_admin_id uuid := (select auth.uid());
  v_transaction_id uuid;
  v_balance numeric;
begin
  if v_admin_id is null or not (select private.is_admin()) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_amount is null or p_amount = 0 or p_description is null
    or char_length(btrim(p_description)) < 2 or char_length(p_description) > 500 then
    raise exception 'A non-zero amount and a short description are required' using errcode = '22023';
  end if;
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'Profile not found' using errcode = '23503';
  end if;
  select coalesce(sum(amount),0) into v_balance from public.point_transactions where user_id=p_user_id;
  if v_balance+p_amount < 0 then
    raise exception 'Adjustment would make balance negative' using errcode = '22023';
  end if;
  insert into public.point_transactions
    (user_id, actor_id, amount, transaction_type, source, description)
  values
    (p_user_id, v_admin_id, p_amount, 'adjustment', 'admin', btrim(p_description))
  returning id into v_transaction_id;
  return v_transaction_id;
end;
$$;

-- 202610250006_brand_onboarding.sql
-- Prototype self-service enrollment. No caller-controlled IDs, role, or status.
-- The profile lock serializes retries; existing memberships are never reactivated.
create or replace function public.open_my_brand(p_name text, p_description text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_role text;
  v_brand uuid;
  v_existing uuid;
  v_name text := btrim(p_name);
  v_description text := btrim(p_description);
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if v_name is null or char_length(v_name) not between 2 and 120
    or v_description is null or char_length(v_description) not between 2 and 2000 then
    raise exception 'Invalid brand details' using errcode = '22023';
  end if;
  select role into v_role from public.profiles where id = v_user for update;
  if not found or v_role = 'admin' then
    raise exception 'A non-admin profile is required' using errcode = '42501';
  end if;

  select bm.brand_id into v_existing from public.brand_memberships bm
  where bm.profile_id = v_user order by bm.created_at, bm.id limit 1;
  if found then
    select bm.brand_id into v_brand from public.brand_memberships bm
    join public.brands b on b.id = bm.brand_id
    where bm.profile_id = v_user and bm.status = 'active' and b.status = 'active'
      and bm.membership_role in ('owner', 'manager')
    order by bm.created_at, bm.id limit 1;
    if v_brand is null then
      raise exception 'Existing membership requires administrator assistance' using errcode = '42501';
    end if;
    update public.profiles set role = 'brand' where id = v_user and role = 'user';
    return v_brand;
  end if;
  -- Also prevent bypass of a suspended brand when its membership was removed.
  if exists (select 1 from public.brands where created_by = v_user) then
    raise exception 'Existing brand requires administrator assistance' using errcode = '42501';
  end if;
  v_brand := gen_random_uuid();
  insert into public.brands(id, name, slug, description, status, created_by)
  values (v_brand, v_name, 'brand-' || replace(v_brand::text, '-', ''), v_description, 'active', v_user);
  insert into public.brand_memberships(brand_id, profile_id, membership_role, status)
  values (v_brand, v_user, 'owner', 'active');
  update public.profiles set role = 'brand' where id = v_user;
  return v_brand;
end;
$$;
revoke all on function public.open_my_brand(text, text) from public, anon;
grant execute on function public.open_my_brand(text, text) to authenticated;

-- 202610250007_brand_campaign_management.sql
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


-- 202610250008_daily_mission_rounds.sql

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


-- 202610250009_daily_mission_seed.sql
-- Repeatable prototype content only. Never overwrite existing mission records.
insert into public.missions(seed_key,title,description,mission_type,activity_type,allowed_activity_types,target_value,target_unit,points,requires_evidence,status,recurrence,difficulty,participation_terms)
values
 ('daily_steps_3000','เดิน 3,000 ก้าว','สะสมการเดิน 3,000 ก้าวภายในวันเดียว แล้วส่งหลักฐานให้ผู้ดูแลตรวจสอบ','steps','steps',array['steps'],3000,'steps',30,true,'active','daily','easy','ทำและส่งผลภายในวันเดียวตามเวลาไทย 00:00–23:59 น. ส่ง URL หรือบันทึกหลักฐานที่ระบุจำนวนก้าวและวันที่ รับ 30 แต้มเมื่อครบและอนุมัติ สูงสุดหนึ่งครั้งต่อรอบวัน'),
 ('daily_exercise_15','ออกกำลังกาย 15 นาที','เดิน วิ่ง ปั่นจักรยาน ว่ายน้ำ หรือออกกำลังกายรูปแบบอื่นให้ครบ 15 นาที','duration','custom',array['walk','run','cycle','swim','custom'],15,'minutes',50,true,'active','daily','medium','เลือกประเภทกิจกรรม ทำและส่งผลภายในวันเดียวตามเวลาไทย ส่ง URL หรือบันทึกหลักฐานที่ระบุชนิดกิจกรรม ระยะเวลา และวันที่ รับ 50 แต้มเมื่อครบและอนุมัติ สูงสุดหนึ่งครั้งต่อรอบวัน'),
 ('daily_walk_run_2km','เดินหรือวิ่ง 2 กิโลเมตร','สะสมระยะทางเดินหรือวิ่งให้ครบ 2 กิโลเมตรภายในวันเดียว','distance','walk',array['walk','run'],2,'km',60,true,'active','daily','medium','เลือกเดินหรือวิ่ง ทำและส่งผลภายในวันเดียวตามเวลาไทย ส่ง URL หรือบันทึกหลักฐานที่ระบุระยะทางและวันที่ รับ 60 แต้มเมื่อครบและอนุมัติ สูงสุดหนึ่งครั้งต่อรอบวัน')
on conflict (seed_key) do nothing;

-- 202610250010_demo_rewards_and_review.sql
create or replace function private.require_rejection_note()
returns trigger language plpgsql set search_path='' as $$
begin
 if old.verification_status='pending' and new.verification_status='rejected'
  and char_length(btrim(coalesce(new.reviewer_note,'')))<2 then
  raise exception 'A rejection reason is required' using errcode='22023';
 end if;
 return new;
end $$;
revoke all on function private.require_rejection_note() from public,anon,authenticated;
drop trigger if exists activities_require_rejection_note on public.activities;
create trigger activities_require_rejection_note before update on public.activities
 for each row execute function private.require_rejection_note();

alter table public.rewards add column if not exists seed_key text unique;
insert into public.rewards(seed_key,title,description,category,points_required,stock,status,expires_at)
values
 ('demo_drink_20','คูปองเดโม: ส่วนลดเครื่องดื่ม 20 บาท','รางวัลสาธิตสำหรับการแข่งขัน ใช้กับร้านค้าจริงไม่ได้ หนึ่งรหัสต่อการแลก ไม่มีการชำระเงินหรือส่งมอบสินค้าจริง','คูปองสาธิต',100,100,'active',now()+interval '365 days'),
 ('demo_sport_10','คูปองเดโม: ส่วนลดอุปกรณ์กีฬา 10%','รางวัลสาธิตสำหรับการแข่งขัน ไม่ได้ร่วมมือกับร้านค้าหรือแบรนด์จริง ใช้กับร้านค้าจริงไม่ได้ หนึ่งรหัสต่อการแลก','คูปองสาธิต',200,100,'active',now()+interval '365 days'),
 ('demo_class_50','คูปองเดโม: ส่วนลดคลาสออกกำลังกาย 50 บาท','รางวัลสาธิตสำหรับการแข่งขัน ใช้จองคลาสจริงไม่ได้ หนึ่งรหัสต่อการแลก ไม่มีการส่งมอบบริการจริง','คูปองสาธิต',300,100,'active',now()+interval '365 days')
on conflict(seed_key) do nothing;
notify pgrst, 'reload schema';
commit;
