begin;
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
