-- Local competition demo data only. These Auth users have no password and cannot sign in.
begin;

insert into auth.users (id, email, raw_user_meta_data)
values
  ('10000000-0000-4000-8000-000000000001', 'nicha@example.test', '{"full_name":"Nicha Demo"}'::jsonb),
  ('10000000-0000-4000-8000-000000000002', 'thanakorn@example.test', '{"full_name":"Thanakorn Demo"}'::jsonb),
  ('10000000-0000-4000-8000-000000000003', 'brand@example.test', '{"full_name":"GreenStep Team"}'::jsonb),
  ('10000000-0000-4000-8000-000000000004', 'admin@example.test', '{"full_name":"Move and Earn Admin"}'::jsonb)
on conflict (id) do nothing;

update public.profiles set role = 'brand'
where id = '10000000-0000-4000-8000-000000000003';
update public.profiles set role = 'admin'
where id = '10000000-0000-4000-8000-000000000004';

insert into public.brands (id, name, slug, description, logo_url, status, created_by)
values (
  '20000000-0000-4000-8000-000000000001', 'GreenStep', 'greenstep',
  'แบรนด์ตัวอย่างสำหรับแคมเปญสุขภาพและการเดิน',
  'https://example.test/greenstep-logo.png', 'active', '10000000-0000-4000-8000-000000000003'
)
on conflict (id) do nothing;

insert into public.brand_memberships (id, brand_id, profile_id, membership_role, status)
values (
  '21000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000003', 'owner', 'active'
)
on conflict (brand_id, profile_id) do nothing;

insert into public.campaigns
  (id, brand_id, name, objective, budget_amount, budget_currency, status, starts_at, ends_at, created_by)
values (
  '30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
  'GreenStep: เดินให้ครบ 5 กิโลเมตร',
  'ชวนผู้ใช้เพิ่มกิจกรรมการเดิน พร้อมวัดการเข้าร่วมและการทำภารกิจให้สำเร็จ',
  25000.00, 'THB', 'active', now() - interval '1 day', now() + interval '30 days',
  '10000000-0000-4000-8000-000000000003'
)
on conflict (id) do nothing;

insert into public.missions
  (id, title, description, mission_type, activity_type, target_value, target_unit,
   points, requires_evidence, status, starts_at, ends_at, created_by)
values (
  '40000000-0000-4000-8000-000000000001', 'เดินให้ครบ 5,000 ก้าว',
  'สะสมจำนวนก้าวให้ถึงเป้าหมายเพื่อรับแต้ม', 'steps', 'steps', 5000, 'steps',
  300, false, 'active', now() - interval '7 days', now() + interval '30 days',
  '10000000-0000-4000-8000-000000000004'
)
on conflict (id) do nothing;

insert into public.challenges
  (id, campaign_id, brand_id, title, description, objective, activity_type, target_value,
   target_unit, reward_points, requires_evidence, participant_limit, status, starts_at, ends_at, created_by)
values (
  '50000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
  'GreenStep 5K', 'เดินหรือวิ่งสะสมระยะทางให้ครบ 5 กิโลเมตร',
  'เพิ่มกิจกรรมทางกายและสร้างการมีส่วนร่วมกับ GreenStep', 'walk', 5, 'km',
  500, true, 1000, 'active', now() - interval '1 day', now() + interval '30 days',
  '10000000-0000-4000-8000-000000000003'
)
on conflict (id) do nothing;

insert into public.rewards
  (id, brand_id, title, description, image_url, category, points_required, stock, status, expires_at, created_by)
values
  ('60000000-0000-4000-8000-000000000001',
   '20000000-0000-4000-8000-000000000001', 'ส่วนลด GreenStep 100 บาท',
   'คูปองส่วนลดสำหรับใช้กับร้านค้าตัวอย่าง', 'https://example.test/rewards/greenstep-100.png',
   'ส่วนลด', 300, 25, 'active', now() + interval '90 days',
   '10000000-0000-4000-8000-000000000003'),
  ('60000000-0000-4000-8000-000000000002',
   null, 'คูปองเครื่องดื่มสุขภาพ', 'คูปองตัวอย่างจาก Move & Earn',
   'https://example.test/rewards/healthy-drink.png', 'อาหารและเครื่องดื่ม',
   450, 50, 'active', now() + interval '90 days',
   '10000000-0000-4000-8000-000000000004')
on conflict (id) do nothing;

insert into public.user_missions
  (id, user_id, mission_id, status, progress_value, joined_at, completed_at)
values (
  '70000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000001', 'completed', 5000,
  now() - interval '2 days', now() - interval '1 day'
)
on conflict do nothing;

insert into public.challenge_participants
  (id, challenge_id, user_id, status, progress_value, joined_at, completed_at)
values
  ('80000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000001', 'completed', 5,
   now() - interval '2 days', now() - interval '1 day'),
  ('80000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000002', 'in_progress', 2,
   now() - interval '1 day', null)
on conflict (challenge_id, user_id) do nothing;

insert into public.activities
  (id, user_id, user_mission_id, activity_type, value, unit, verification_status, reviewed_by, reviewed_at)
values (
  '90000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001', 'steps', 5000, 'steps', 'approved',
  '10000000-0000-4000-8000-000000000004', now() - interval '1 day'
)
on conflict (id) do nothing;

insert into public.activities
  (id, user_id, challenge_participant_id, activity_type, value, unit, evidence_url,
   verification_status, reviewed_by, reviewed_at)
values (
  '90000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
  '80000000-0000-4000-8000-000000000001', 'walk', 5, 'km',
  'https://example.test/evidence/greenstep-demo.png', 'approved',
  '10000000-0000-4000-8000-000000000003', now() - interval '1 day'
),
(
  '90000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000002',
  '80000000-0000-4000-8000-000000000002', 'walk', 2, 'km',
  'https://example.test/evidence/greenstep-pending.png', 'pending', null, null
)
on conflict (id) do nothing;

insert into public.redemptions
  (id, user_id, reward_id, points_spent, status, redemption_code, created_at)
values (
  'a0000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
  '60000000-0000-4000-8000-000000000001', 300, 'requested', 'DEMO-ME-0001', now() - interval '12 hours'
)
on conflict (id) do nothing;

-- Seed the wallet ledger once per source activity or redemption; point history is append-only.
insert into public.point_transactions
  (id, user_id, actor_id, amount, transaction_type, source, reference_id, activity_id, description, created_at)
values
  ('b0000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000004', 300, 'earn', 'mission',
   '90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001',
   'Mission completed: เดินให้ครบ 5,000 ก้าว', now() - interval '1 day'),
  ('b0000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000003', 500, 'earn', 'challenge',
   '90000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000002',
   'Challenge completed: GreenStep 5K', now() - interval '1 day')
on conflict (id) do nothing;

insert into public.point_transactions
  (id, user_id, actor_id, amount, transaction_type, source, reference_id, redemption_id, description, created_at)
values (
  'b0000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001', -300, 'spend', 'redemption',
  'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001',
  'Reward redeemed: ส่วนลด GreenStep 100 บาท', now() - interval '12 hours'
)
on conflict (id) do nothing;

update public.rewards set stock = 24
where id = '60000000-0000-4000-8000-000000000001'
  and exists (select 1 from public.redemptions r
    where r.id = 'a0000000-0000-4000-8000-000000000001');

commit;
