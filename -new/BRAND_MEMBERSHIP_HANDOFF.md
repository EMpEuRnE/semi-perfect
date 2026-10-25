# ระบบสมาชิกแบรนด์ — ส่งมอบ

## พฤติกรรมใหม่

- `/register` เลือกสมัครผู้ใช้หรือแบรนด์ได้
- `/register?account=brand` เก็บชื่อแบรนด์และรายละเอียดเป็น draft ใน Auth metadata โดยไม่ส่ง role หรือสิทธิ์ admin
- ถ้า Supabase ต้องยืนยันอีเมล ให้ยืนยันก่อน ระบบ callback จะนำไป `/open-brand`; ถ้าสมัครแล้วมี session จะไปหน้านี้ทันที
- `/open-brand` ต้องล็อกอิน กรอกรายละเอียดและยืนยันการเปิดแบรนด์อย่างชัดเจน
- Prototype เปิดแบรนด์ใหม่เป็น active ทันทีหลังยืนยัน ไม่ใช่การรับรองตัวตนหรือความเป็นเจ้าของเครื่องหมายการค้า
- Backend `open_my_brand` สร้าง Brand + active Owner membership + เปลี่ยน profile จาก user เป็น brand ใน transaction เดียว
- ไม่รับ user ID, brand ID, role หรือ status จาก client; ใช้ auth.uid() เท่านั้น
- ล็อก profile เพื่อ serialize การเปิดซ้ำ และคืนแบรนด์ที่มีอยู่สำหรับ owner/manager ที่ active โดยไม่เปลี่ยนชื่อหรือรายละเอียดจาก retry
- สมาชิกที่ suspended/invited หรือแบรนด์เดิมที่ยังไม่ active ต้องให้ผู้ดูแลตรวจสอบ ไม่เปิดแบรนด์ใหม่เพื่อหลบการระงับ
- บัญชี admin ไม่ถูกเปลี่ยนเป็น brand; ใช้บัญชีแยกสำหรับเดโม
- บัญชีเดิมเปิดแบรนด์จากหน้าโปรไฟล์ได้ ไม่ลบ Wallet, activities หรือประวัติ
- Login โดยไม่ระบุปลายทาง: active Brand ไป `/brand`, User ไป `/profile`, Admin ไป `/admin`
- หน้า Brand ตรวจทั้ง profile role และ active membership ของ active brand; Server Actions และ RLS เดิมยังตรวจสิทธิ์การเขียนแต่ละแบรนด์
- หน้าผู้ใช้มีลิงก์เปิดแบรนด์/จัดการแบรนด์ตามสิทธิ์จริง รวมบนมือถือ

## ติดตั้งบนฐานข้อมูลเดิม

1. ใช้โค้ดใหม่นี้ และเก็บ `.env.local` จากโปรเจกต์เดิมบนเครื่องไว้
2. ใน Supabase SQL Editor รัน **เฉพาะ** `supabase/migrations/202610250006_brand_onboarding.sql` ด้วยสิทธิ์เจ้าของโปรเจกต์ หลัง migrations เดิมทั้ง 10 ไฟล์
3. Migration เพิ่มฟังก์ชันและสิทธิ์ execute พร้อม notify schema cache ไม่ลบตาราง ไม่แก้บัญชีใดล่วงหน้า
4. ไม่ต้องรัน INSTALL_FRESH.sql หรือ seed.sql บนโปรเจกต์ที่มีข้อมูลแล้ว
5. Restart เว็บ จากนั้นใช้บัญชีเดิมเปิด `/open-brand` หรือสมัครบัญชีแบรนด์ใหม่

INSTALL_FRESH.sql อัปเดตให้รวมฟังก์ชันใหม่สำหรับฐานข้อมูลว่างเท่านั้น ส่วน migration history เก่าไม่ถูกแก้

## เปิดโปรเจกต์บน Windows

ZIP มีโฟลเดอร์ Move-and-earn-brand-membership ที่ภายในมี package.json ให้เปิดโฟลเดอร์นี้โดยตรง
คัดลอก `.env.local` จากโฟลเดอร์เดิมมาไว้ข้าง package.json ไม่ต้องส่งค่าหรือ commit ไฟล์นี้

ถ้าติดตั้ง Node.js แล้วแต่ Terminal ยังหา npm ไม่พบ ให้ปิด VS Code ทุกหน้าต่างและเปิดใหม่
ติดตั้ง dependencies ด้วยวิธี hoisted ที่ใช้ผ่านบนเครื่องผู้ใช้แล้ว:

```powershell
npm.cmd exec --yes --package=pnpm@11.25.0 -- pnpm install --frozen-lockfile --node-linker=hoisted
```

เปิดเว็บโดยตรง:

```powershell
.\node_modules\.bin\next.cmd dev
```

ใช้ URL หลัง Local: ที่ Terminal แสดง ไม่จำเป็นต้องเปิด START.cmd เดิม; Windows launcher เดิมไม่ได้ปรับในงานสมาชิกแบรนด์นี้

## การทดสอบจริงในรอบนี้

| การตรวจ | ผลและขอบเขต |
|---|---|
| pnpm check | ผ่าน typecheck, lint, unit, SQL และ production build ตามลำดับ |
| unit | 41 checks: redirect 10, environment 13, brand Auth/actions 18 |
| SQL | 70 assertions บน PGlite / embedded PostgreSQL พร้อม auth.uid() จำลอง |
| HTTP | 21 checks บน production server แบบไม่ตั้งค่า Supabase |
| Fresh installer | ติดตั้งครบและเปิดแบรนด์จากฟังก์ชันใหม่ผ่านใน PGlite |

Brand Auth/actions ใช้โค้ด Server Actions จริง แต่แทน Supabase Auth/database ด้วย test doubles: ทดสอบสมัครแบบมี/ไม่มี session, callback destination, validation, role spoofing, login destination, denied guards, confirmation และ backend error mapping

SQL ทดสอบเปิดแบรนด์ใหม่, retry, metadata ที่ปลอม role, direct privilege escalation, สร้าง Campaign/Challenge หลังเปิดแบรนด์, สองแบรนด์อ่าน/เขียน Campaign/Challenge ของอีกแบรนด์ไม่ได้, เก็บแต้ม/ประวัติของผู้ใช้เดิม และป้องกัน bypass suspension

HTTP ทดสอบหน้า public, redirect ของหน้า protected รวม /open-brand, การแยกฟอร์มสมัคร และการปฏิเสธ Auth actions เมื่อไม่ตั้งค่าระบบ

ระหว่างตรวจเคยรัน typecheck พร้อม build แล้ว generated types ถูก build สร้างใหม่จนเกิด transient file-not-found; รัน `pnpm check` แบบเรียงลำดับแล้วผ่านทั้งหมด ไม่แก้ source เพื่อหลบการตรวจ

## ยังไม่ได้ยืนยัน

- ยังไม่ได้รัน migration ใหม่บน Supabase จริง
- ยังไม่ได้สมัคร/ล็อกอินหรือยืนยันอีเมลกับ Supabase จริงในรอบนี้
- ยังไม่ได้ตรวจภาพ desktop/mobile หรือ flow หลังล็อกอินใน browser จริง
- ยังไม่ได้ทดสอบหลาย connection พร้อมกันบน PostgreSQL จริง; มี profile lock ใน SQL แต่ผลทดสอบนี้ไม่ใช่ concurrency test
- ยังไม่ได้ deploy หรือ push branch ขึ้น GitHub

ไม่ใช้ service-role key และไม่แสดงค่า environment ในรายงาน ZIP ไม่รวม .env.local, node_modules, .next หรือประวัติ Git

## ตรวจบน Supabase หลังติดตั้ง

1. สมัคร User ปกติ: ต้องไม่มีสิทธิ์หน้า /brand และสร้าง Campaign ของใครไม่ได้
2. สมัคร Brand: ยืนยันอีเมลถ้าระบบกำหนด แล้วกดยืนยันเปิดแบรนด์; ต้องเห็นประเภทแบรนด์และสร้าง Campaign ของตนเองได้
3. ออกจากระบบแล้วเข้าใหม่: ต้องไปพื้นที่ Brand ได้จาก role + membership จริง
4. เปิด Brand จาก User เดิม: แต้มและประวัติต้องเท่าเดิม
5. ใช้ Brand A/B แยกกัน: ตรวจ draft Campaign/Challenge ของอีกแบรนด์ต้องมองไม่เห็นและเขียนไม่ได้
6. ผู้ดูแลระงับ Brand หรือ membership: ต้องสร้าง Campaign ไม่ได้ และเปิดซ้ำเพื่อปลดระงับเองไม่ได้

ขอบเขตงานนี้จบที่สมาชิกแบรนด์ ไม่เพิ่ม Daily Missions, Progress page หรือคูปองใหม่
