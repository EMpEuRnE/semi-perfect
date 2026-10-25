> Demo update: see [DEMO_HANDOFF.md](DEMO_HANDOFF.md) for executed tests, known blockers and deployment steps.

# Move & Earn

พื้นฐานแอป Move & Earn ด้วย Next.js App Router, TypeScript, Tailwind CSS และ Supabase Auth

## เริ่มใช้งาน

1. ติดตั้ง Node.js 22 ขึ้นไป และ pnpm
2. ติดตั้งแพ็กเกจด้วย `pnpm install`
3. คัดลอกไฟล์ตัวอย่างตัวแปรแวดล้อมเป็น `.env.local` แล้วใส่ Supabase Project URL และ Publishable key
   - PowerShell: `Copy-Item .env.example .env.local`
   - ค่าทั้งสองดูได้จากหน้า Connect หรือ API settings ของโปรเจกต์ Supabase
4. ตั้งค่า URL callback สำหรับยืนยันอีเมลใน Supabase Auth ให้ชี้มาที่ `http://localhost:3000/auth/callback`
5. เริ่มแอปด้วย `pnpm dev` แล้วเปิด `http://localhost:3000`

ถ้ายังไม่ได้ตั้งค่า Supabase หน้าแอปและหน้าตัวอย่างจะเปิดดูได้ แต่การสมัครและเข้าสู่ระบบจะยังใช้งานไม่ได้

## โครงสร้างหลัก

- `src/app/(user)` — หน้าสำหรับผู้ใช้
- `src/app/brand` — หน้าสำหรับแบรนด์ ซึ่งตรวจ role ก่อนแสดงเนื้อหา
- `src/app/actions` — Server Actions สำหรับการยืนยันตัวตน
- `src/components` — UI และ navigation ที่นำกลับมาใช้ซ้ำ
- `src/lib/supabase` — Supabase client สำหรับ browser, server และ session refresh
- `src/lib/auth` — การอ่าน session และ guard สำหรับเส้นทางที่ต้องลงชื่อเข้าใช้

role `brand`/`admin` ต้องถูกกำหนดผ่านขั้นตอนดูแลระบบที่เชื่อถือได้ ห้ามกำหนด role สิทธิ์สูงจากฟอร์มสมัครสมาชิกหรือ metadata ที่ผู้ใช้ควบคุม รายละเอียด schema และ RLS อยู่ในหัวข้อฐานข้อมูลด้านล่าง

## ความปลอดภัยของคีย์

ใช้เฉพาะ Publishable key ในตัวแปร `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` ซึ่งถูกส่งไปยัง browser ได้เมื่อเปิดใช้ RLS และเขียน policy อย่างเหมาะสม ห้ามใส่ Secret key หรือ service-role key ในตัวแปรที่ขึ้นต้นด้วย `NEXT_PUBLIC_` หรือใน repository นี้

## ฐานข้อมูล Supabase

โครงสร้างฐานข้อมูลอยู่ใน `supabase/` และแยก migration ตามลำดับเวลา:

- `202610240001_core_entities.sql` — โปรไฟล์ แบรนด์ สมาชิกแบรนด์ แคมเปญ ภารกิจ และชาเลนจ์
- `202610240002_participation_rewards_ledger.sql` — การเข้าร่วม กิจกรรม รางวัล การแลก และบัญชีแต้ม
- `202610240003_authorization_and_policies.sql` — RLS, สิทธิ์ตาราง และการสร้างโปรไฟล์จาก Supabase Auth
- `202610240004_secure_workflows.sql` — ฟังก์ชันเข้าร่วม ตรวจผล ให้/หักแต้ม แลกรางวัล และคืนแต้ม
- `202610240005_reporting_views.sql` — ยอดแต้มและผลแคมเปญสำหรับรายงาน

โมเดลเพิ่ม `brands` และ `brand_memberships` เพื่อแยกสิทธิ์ตามองค์กร แคมเปญผูกกับแบรนด์ ชาเลนจ์ผูกกับทั้งแคมเปญและแบรนด์ ส่วนการส่งกิจกรรมแต่ละครั้งต้องอ้างถึงการเข้าร่วมภารกิจหรือชาเลนจ์อย่างใดอย่างหนึ่ง แต้มเก็บเป็นรายการใน `point_transactions` ซึ่งแก้ไขหรือลบย้อนหลังไม่ได้ ยอดคงเหลือคำนวณจาก ledger

ผู้ใช้ทั่วไปไม่มีสิทธิ์เพิ่มหรือแก้รายการแต้มโดยตรง ฟังก์ชันฐานข้อมูล `review_activity`, `redeem_reward`, `refund_redemption` และ `admin_adjust_points` ทำรายการภายใน transaction พร้อมตรวจสิทธิ์ ล็อกแถวที่เกี่ยวข้อง และบันทึก ledger ส่วน `campaign_results` จำกัดผลรายงานไว้สำหรับสมาชิกแบรนด์ที่มีสิทธิ์หรือ admin

### รัน migration และข้อมูลสาธิตในเครื่อง

ติดตั้ง Docker Desktop และเปิด Docker ให้ทำงานก่อน จากนั้นเรียก Supabase CLI ที่ติดตั้งไว้ในโครงการ:

```powershell
pnpm supabase start
pnpm supabase db reset
```

คำสั่ง reset สร้างฐานข้อมูล local ใหม่ รัน migration ตามลำดับ และใส่ข้อมูลจาก `supabase/seed.sql` ตัวอย่างประกอบด้วยผู้ใช้ 2 คน บัญชีแบรนด์และ admin ภารกิจ ชาเลนจ์ แคมเปญ รางวัล กิจกรรม และประวัติแต้มที่แสดงยอดหลังแลกรางวัลแล้ว

บัญชีใน seed ใช้อีเมลโดเมน `.test` และไม่มีรหัสผ่าน จึงเป็นข้อมูลตัวอย่างสำหรับตรวจฐานข้อมูล ไม่สามารถเข้าสู่ระบบได้ หากต้องการบัญชีที่ล็อกอินได้ ให้สร้างบัญชีผ่าน Supabase Auth ในเครื่องก่อน โดย trigger จะสร้างแถว `profiles` ให้โดยอัตโนมัติ จากนั้นกำหนด role และสมาชิกแบรนด์ผ่านขั้นตอนดูแลระบบที่เชื่อถือได้ การกำหนด `role` จาก metadata ของผู้ใช้ถูกละเว้น

ไฟล์ migration ใช้ได้กับ Supabase local และโปรเจกต์ที่โฮสต์ไว้ แต่คำสั่งข้างต้นไม่ deploy ไปยังโปรเจกต์จริง หากสร้าง Supabase project ใหม่ให้เลือกภูมิภาค Singapore ตอนสร้างโปรเจกต์ แล้วตรวจ URL/key ใน `.env.local` ด้วยตนเองก่อนเชื่อมแอป
