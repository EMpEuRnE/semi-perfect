begin;

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

commit;
