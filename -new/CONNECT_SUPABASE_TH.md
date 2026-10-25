# เชื่อมต่อ Supabase — สถานะล่าสุด

ตั้งค่า .env.local ตามค่าที่เจ้าของโปรเจกต์ให้แล้ว ไฟล์นี้ถูก gitignore

ตรวจจริง: Auth settings ตอบ HTTP 200 และเปิด email Auth
API ของ profiles, missions, rewards, challenges, campaigns และ point_transactions ตอบ PGRST205 (ไม่พบใน schema cache)
จึงยังไม่ยืนยันว่าฐานข้อมูลพร้อมใช้งาน และยังไม่สร้างตารางจากระยะไกล
Publishable key ไม่มีสิทธิ์รัน DDL หรือ migrations

## ขั้นตอนต่อไป

1. เปิดโปรเจกต์ Supabase ของคุณ แล้วเข้า SQL Editor
2. เปิดไฟล์ supabase/INSTALL_FRESH.sql ใน VS Code แล้วคัดลอกเนื้อหาทั้งหมด
3. วางใน SQL Editor และ Run
4. ถ้าแจ้งว่าพบตารางเดิม ให้หยุด ไม่ต้องลบหรือรีเซ็ต แล้วส่งข้อความ error มา
5. เมื่อตั้งค่าผ่าน ให้กลับมาดำเนินการสร้างข้อมูลเดโมและบัญชีจริงต่อ

INSTALL_FRESH.sql รวม migrations 10 ไฟล์ใน transaction เดียว และปฏิเสธการทำงานหากพบตาราง Move & Earn อยู่ก่อน เพื่อป้องกันการทับข้อมูล ไม่รวม seed.sql ซึ่งมีบัญชี Auth fixture ที่ไม่มีรหัสผ่าน

หากติดตั้งผ่าน SQL Editor ต้องบันทึกไว้ว่าใช้ migrations ใดแล้ว ก่อนใช้ supabase db push ภายหลัง อย่า replay migrations ทั้งหมดซ้ำ เพราะ SQL Editor ไม่บันทึก CLI migration history อัตโนมัติ

ไฟล์พรีวิวแบบ static ที่เผยแพร่ก่อนหน้านี้ยังไม่ใช่แอปที่เชื่อมฐานข้อมูล
เปิดโปรเจกต์นี้ใน VS Code แล้วรัน pnpm dev เพื่อใช้ Next.js จริง
Production deployment และ Authenticated E2E ยังต้องทดสอบหลังตั้งค่าฐานข้อมูล
