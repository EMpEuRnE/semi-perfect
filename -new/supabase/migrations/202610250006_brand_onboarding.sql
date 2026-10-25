begin;

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

notify pgrst, 'reload schema';
commit;
