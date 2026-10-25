begin;

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

commit;
