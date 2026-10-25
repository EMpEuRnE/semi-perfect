-- Repeatable prototype content only. Never overwrite existing mission records.
begin;
insert into public.missions(seed_key,title,description,mission_type,activity_type,allowed_activity_types,target_value,target_unit,points,requires_evidence,status,recurrence,difficulty,participation_terms)
values
 ('daily_steps_3000','เดิน 3,000 ก้าว','สะสมการเดิน 3,000 ก้าวภายในวันเดียว แล้วส่งหลักฐานให้ผู้ดูแลตรวจสอบ','steps','steps',array['steps'],3000,'steps',30,true,'active','daily','easy','ทำและส่งผลภายในวันเดียวตามเวลาไทย 00:00–23:59 น. ส่ง URL หรือบันทึกหลักฐานที่ระบุจำนวนก้าวและวันที่ รับ 30 แต้มเมื่อครบและอนุมัติ สูงสุดหนึ่งครั้งต่อรอบวัน'),
 ('daily_exercise_15','ออกกำลังกาย 15 นาที','เดิน วิ่ง ปั่นจักรยาน ว่ายน้ำ หรือออกกำลังกายรูปแบบอื่นให้ครบ 15 นาที','duration','custom',array['walk','run','cycle','swim','custom'],15,'minutes',50,true,'active','daily','medium','เลือกประเภทกิจกรรม ทำและส่งผลภายในวันเดียวตามเวลาไทย ส่ง URL หรือบันทึกหลักฐานที่ระบุชนิดกิจกรรม ระยะเวลา และวันที่ รับ 50 แต้มเมื่อครบและอนุมัติ สูงสุดหนึ่งครั้งต่อรอบวัน'),
 ('daily_walk_run_2km','เดินหรือวิ่ง 2 กิโลเมตร','สะสมระยะทางเดินหรือวิ่งให้ครบ 2 กิโลเมตรภายในวันเดียว','distance','walk',array['walk','run'],2,'km',60,true,'active','daily','medium','เลือกเดินหรือวิ่ง ทำและส่งผลภายในวันเดียวตามเวลาไทย ส่ง URL หรือบันทึกหลักฐานที่ระบุระยะทางและวันที่ รับ 60 แต้มเมื่อครบและอนุมัติ สูงสุดหนึ่งครั้งต่อรอบวัน')
on conflict (seed_key) do nothing;
notify pgrst, 'reload schema';
commit;
