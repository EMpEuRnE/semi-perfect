begin;

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

commit;
