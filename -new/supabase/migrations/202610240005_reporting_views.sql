begin;

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

commit;
