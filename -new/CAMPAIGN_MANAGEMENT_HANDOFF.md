# Campaign และ Challenge — ส่งมอบขั้นที่ 3

วันที่ 25 ตุลาคม 2026 · ต่อจาก feature/brand-membership

## สิ่งที่เปลี่ยน

- ฟอร์ม Campaign: ชื่อ รายละเอียด วันเริ่ม/สิ้นสุด เวลาไทย UTC+7
- ฟอร์ม Challenge: เลือก Campaign ของตนเอง ชื่อ รายละเอียด ชื่อภารกิจ ประเภทกิจกรรม เป้าหมาย หน่วย เงื่อนไข หลักฐาน แต้มเมื่อสำเร็จ วันเริ่ม/สิ้นสุด จำนวนผู้เข้าร่วม และรางวัลแนะนำ
- แต่ละ Challenge มีหนึ่งภารกิจ/เป้าหมายตามโครงสร้างเดิม Campaign สร้างหลาย Challenge ได้ โดยไม่สร้างหรือแก้ Mission ส่วนกลาง
- จำนวนผู้เข้าร่วมว่าง = null = ไม่จำกัด; ใส่ค่าต้องเป็นจำนวนเต็มบวก
- รางวัลแนะนำเลือกจาก Reward ที่ผูกแบรนด์เดียวกัน ไม่ใช่แจกคูปองเมื่อสำเร็จ สำเร็จและตรวจผ่านแล้วได้แต้ม ผู้ใช้กดแลกรางวัลแยกตามราคา สต็อก และเงื่อนไขขณะแลก
- ไม่เพิ่มตัวจัดการ Reward หรือคูปองใหม่ในขั้นนี้ ถ้าแบรนด์ยังไม่มี Reward เลือกให้ผู้ใช้นำแต้มไปดูหน้ารางวัลภายหลังได้
- ตรวจ activity/unit, จำนวนที่เป็นบวก/finite, ความละเอียด target, จำนวนเต็มในหน่วยก้าว/ครั้ง, วันปฏิทิน และลำดับวัน ที่ Server Action และ/หรือ constraints/triggers
- Challenge ต้องอยู่ในช่วง Campaign; Campaign แก้เวลาให้ตัดช่วงของ Challenge เดิมออกไม่ได้
- หน้ารวมแสดงรายละเอียด เงื่อนไข เวลา จำนวนผู้เข้าร่วม สถานะ แต้ม รางวัลแนะนำ ผู้เข้าร่วม และผลลัพธ์พื้นฐาน
- ผู้เข้าร่วมเห็นเงื่อนไขจริงก่อน Join รวมถึงคำอธิบายหลักฐานและรางวัลที่ต้องแลกแยก
- มี pending buttons, loading เดิมของ /brand, error notices, empty states และ success notice; ใช้ layout คอลัมน์เดียวบนจอเล็กและสองคอลัมน์บนจอใหญ่

## กติกาการแก้ไขและสถานะ

| สถานการณ์ | พฤติกรรม |
|---|---|
| สร้าง | เป็น draft ตาม default ของฐานข้อมูล |
| เผยแพร่ | draft/scheduled/paused → active; Challenge ต้องมี Campaign active และยังไม่หมดอายุ |
| หยุดรับ | active/scheduled → paused; หยุดคนใหม่ ผู้เข้าร่วมเดิมส่งกิจกรรมภายในเวลาเดิมได้ |
| เปิดใหม่ | paused → active โดยตรวจ Campaign และวันหมดอายุอีกครั้ง |
| ก่อนมีผู้เข้าร่วม | แก้รายละเอียดและเงื่อนไขผ่านฟอร์มได้ |
| หลังมีผู้เข้าร่วมอย่างน้อยหนึ่งรายการ | ล็อกชื่อ/รายละเอียด ภารกิจ เป้าหมาย/หน่วย แต้ม หลักฐาน เงื่อนไข ที่นั่ง วัน และ Reward; Campaign ล็อกเงื่อนไขด้วย |
| completed | ยืนยันปิดผ่าน UI; ต้องไม่มีหลักฐานรอตรวจ และไม่มีผู้เข้าร่วมที่ยังทำไม่เสร็จ เว้นแต่สิ้นสุดระยะเวลาที่ตกลงไว้แล้ว |
| หลัง completed | เปิดใหม่หรือแก้เงื่อนไขไม่ได้ Campaign รับ Challenge ใหม่ไม่ได้ |

ข้อจำกัดนี้บังคับด้วย database triggers ด้วย ไม่ใช่เพียงซ่อนปุ่มแก้ไข การแก้ชื่อเพื่อแก้คำผิดหลังมีผู้เข้าร่วมก็ถูกล็อกโดยตั้งใจ ให้สร้างรายการใหม่แทน

คงการอนุมัติหลักฐานค้างผ่าน review_activity ตามสิทธิ์เดิม ไม่มีการให้แต้มจากการกด completed ของผู้จัดโดยตรง

## สิทธิ์และที่นั่ง

- ใช้ requireRole + active Brand membership จากขั้นก่อน และ RLS ของ Campaign/Challenge เดิม
- Client ส่ง ID มาได้ แต่ backend/RLS ตรวจเจ้าของจากข้อมูลจริง การแก้ฟอร์มไม่ส่ง brand_id/campaign_id กลับไปเปลี่ยนเจ้าของ
- แบรนด์สร้าง Mission ส่วนกลางไม่ได้
- Reward ต้องเป็นของแบรนด์เดียวกัน ตรวจใน trigger เพื่อป้องกันปลอม ID ผ่าน REST
- รายการ active ที่เปิดเผยเพื่อค้นหายังอ่านได้ตามนโยบายเดิม; รายการ private/draft ของแบรนด์อื่นอ่านหรือเขียนไม่ได้
- เพิ่ม policy ให้ผู้เข้าร่วมอ่าน Challenge ของตนเองขณะ paused/completed ได้ ผ่าน helper SECURITY DEFINER ที่ตรวจ auth.uid() เพื่อไม่เกิด RLS recursion
- join_challenge ล็อก Campaign แบบ share ก่อน และล็อก Challenge แบบ update ก่อนนับที่นั่ง; การแก้/ปิด Campaign ต้องรอล็อกนี้
- การแก้ Challenge และ Join ใช้แถว Challenge เดียวกัน จึงป้องกันการแก้เงื่อนไขแทรกระหว่างการจอง
- retry Join คืน participation เดิม ไม่กินที่นั่งเพิ่ม
- เพดานนับรายการที่เคยเข้าร่วมทั้งหมดตามระบบเดิม ไม่คืนที่นั่งอัตโนมัติเมื่อยกเลิก

ยังไม่ได้ทดสอบ race หลาย connection บน PostgreSQL จริง จึงไม่รายงานว่า concurrency test ผ่าน ผลทดสอบที่นั่งด้านล่างเป็นการเรียกตามลำดับใน embedded PostgreSQL

## การติดตั้งฐานข้อมูลเดิม

1. เก็บ .env.local เดิมและสำรองโฟลเดอร์เดิมไว้
2. ถ้ายังไม่ได้ติดตั้งขั้นสมาชิกแบรนด์ ให้รัน `supabase/migrations/202610250006_brand_onboarding.sql` ก่อน
3. รันเฉพาะ `supabase/migrations/202610250007_brand_campaign_management.sql` หนึ่งครั้งใน Supabase SQL Editor ด้วยสิทธิ์เจ้าของโปรเจกต์
4. Migration เพิ่ม columns, FK, grants, triggers, participant discovery policy และปรับ RPC; ไม่ reset ตารางหรือใส่ demo users
5. ไม่รัน INSTALL_FRESH.sql หรือ seed.sql กับฐานข้อมูลที่มีข้อมูลอยู่
6. เปิดโค้ดใหม่และ restart server หากไม่พบฟิลด์ใหม่ให้ตรวจว่ารัน migration สำเร็จแล้ว

INSTALL_FRESH.sql อัปเดตให้รวม migration ใหม่สำหรับฐานข้อมูลว่างเท่านั้น ไม่แก้ไฟล์ migration เก่าที่เคยนำไปใช้แล้ว

## เปิดบน Windows

แตก ZIP แล้วเปิดโฟลเดอร์ `Move-and-earn-brand-campaigns` ที่มี package.json โดยตรง คัดลอก `.env.local` จากโฟลเดอร์เดิมมาไว้ข้าง package.json

```powershell
npm.cmd exec --yes --package=pnpm@11.25.0 -- pnpm install --frozen-lockfile --node-linker=hoisted
```

```powershell
.\node_modules\.bin\next.cmd dev
```

เปิด Local URL ที่แสดงใน Terminal และเปิด Terminal ค้างไว้ ไม่ต้องใช้ START.cmd เดิมในขั้นนี้

## ผลทดสอบจริง

| ชุดตรวจ | ผล |
|---|---|
| lint / typecheck / production build | ผ่าน |
| unit/validation/action checks | 72 checks ผ่าน: 10 redirects + 13 env + 18 Brand Auth + 31 authoring |
| database integration | 111 assertions ผ่านบน PGlite พร้อม auth.uid() จำลอง |
| HTTP บน production server | 21 checks ผ่าน แบบไม่ตั้งค่า Supabase |
| INSTALL_FRESH.sql | ติดตั้ง schema รวม columns และ triggers ใหม่ได้ใน PGlite |

Database tests ครอบคลุมสร้าง draft, แก้ก่อนมีผู้เข้าร่วม, เผยแพร่ parent ก่อน child, ช่วงเวลาและหน่วยที่ผิด, non-finite target, รางวัลข้ามแบรนด์, ห้ามสร้าง Mission ส่วนกลาง, ข้ามแบรนด์อ่าน/แก้/เผยแพร่ draft ไม่ได้, Join retry, ที่นั่งสุดท้ายและการปฏิเสธคนถัดไป, ล็อกเงื่อนไข, pause/resume, ผู้เข้าร่วมเดิมส่งกิจกรรมระหว่าง pause, หลักฐานที่ต้องส่ง, อนุมัติแล้วได้แต้ม และ completion/final-state guards

Action checks ใช้โค้ดจริงกับ database/Auth doubles ไม่ใช่การทดสอบ Supabase Auth จริง ส่วน HTTP ตรวจ public pages/unauthenticated protection ไม่ครอบคลุมหน้าจัดการหลังล็อกอิน

## สิ่งที่ยังไม่ได้ยืนยัน

- ไม่ได้รัน migration หรือแก้ข้อมูลใน Supabase จริง
- ไม่ได้ทดสอบบัญชีจริงครบ flow ผ่าน browser หรือ multi-connection concurrency บน PostgreSQL จริง
- ตรวจ code responsive แล้ว แต่ visual QA desktop/mobile ยังทำไม่ได้: ไม่มี Chromium และการดาวน์โหลด Chromium ส่งไฟล์ที่แตก ZIP ไม่ได้ จึงไม่อ้างว่าตรวจภาพผ่าน
- ยังไม่ได้ deploy หรือ push branch ขึ้น GitHub

## เดโมหลังติดตั้ง

1. ล็อกอิน Brand A เปิด /brand สร้าง Campaign โดยวันเริ่มเป็นอดีตเล็กน้อยและวันจบอนาคต
2. สร้าง Challenge ใต้ Campaign นั้น กำหนดภารกิจเดิน 1 km, 90 แต้ม, 1 ที่นั่ง และเงื่อนไข/หลักฐาน
3. แก้ฉบับร่างหนึ่งครั้ง แล้วเผยแพร่ Campaign ก่อน Challenge
4. User A เข้าร่วม; User B ต้องเข้าไม่ได้เพราะเต็ม
5. Brand A ลองแก้เป้าหมายหรือแต้ม: ต้องถูกปฏิเสธ
6. Brand A หยุดรับใหม่; User A ยังส่งหลักฐานภายในเวลาเดิมได้
7. Brand A อนุมัติ User A: ได้แต้มจาก backend เมื่อครบเป้าหมาย
8. เมื่อไม่มีงานค้าง ปิด Challenge และ Campaign เป็น completed
9. Brand B ลองแก้ Campaign/Challenge ของ A: ต้องไม่มีสิทธิ์

ZIP ไม่รวม .env.local, node_modules, .next หรือประวัติ Git งานนี้ไม่เพิ่ม Daily Missions, หน้า Progress รวม หรือคูปองชุดใหม่
