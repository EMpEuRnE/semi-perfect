import Link from "next/link";
import { requireAuthenticatedUser } from "@/lib/auth/guards";
import { getUserProfile } from "@/lib/auth/session";
import { hasActiveBrandMembership } from "@/lib/auth/brand-access";
import { createClient } from "@/lib/supabase/server";
import { openBrandAction } from "@/app/actions/brand-onboarding";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { Container } from "@/components/ui/container";
import { Card } from "@/components/ui/card";

export const dynamic = "force-dynamic";
const errors: Record<string, string> = {
  input: "กรอกชื่อแบรนด์ 2–120 ตัวอักษร รายละเอียด 2–2,000 ตัวอักษร และยืนยันการเปิดแบรนด์",
  migration: "ยังไม่ได้ติดตั้ง migration ระบบสมาชิกแบรนด์ กรุณาให้ผู้ดูแลรัน 202610250006_brand_onboarding.sql",
  membership: "บัญชีนี้มีแบรนด์หรือสมาชิกเดิมที่ต้องตรวจสอบ กรุณาติดต่อผู้ดูแล ไม่สามารถเปิดซ้ำเพื่อปลดสถานะระงับได้",
  save: "เปิดแบรนด์ไม่สำเร็จ กรุณาลองใหม่ ข้อมูลผู้ใช้และประวัติเดิมยังอยู่",
};

export default async function OpenBrandPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const user = await requireAuthenticatedUser("/open-brand");
  const [profile, active, params] = await Promise.all([getUserProfile(user.id), hasActiveBrandMembership(user.id), searchParams]);
  const db = await createClient();
  const { data, error } = await db.auth.getUser();
  // Auth metadata supplies editable draft text only; it never grants privileges.
  const draft = !error ? data.user?.user_metadata : null;
  const inputClass = "mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white p-3 font-normal";
  return <Container className="py-10"><Card className="mx-auto max-w-2xl space-y-5 p-6 sm:p-9">
    <h1 className="text-3xl font-semibold">เปิดบัญชีแบรนด์</h1>
    <p>สำหรับ prototype: หลังเข้าสู่ระบบและยืนยันแบบฟอร์มนี้ แบรนด์จะเปิดใช้งานทันที ไม่ใช่การรับรองแบรนด์โดยแพลตฟอร์ม</p>
    <p className="text-sm text-slate-600">ใช้บัญชีเดิมได้ แต้ม ภารกิจ และประวัติของคุณจะยังอยู่ เจ้าของแบรนด์จัดการได้เฉพาะแบรนด์ของตนเอง</p>
    {params.error && <p role="alert" className="rounded-xl bg-rose-50 p-3 text-rose-800">{errors[params.error] ?? errors.save}</p>}
    {!profile || error ? <p role="alert">โหลดข้อมูลบัญชีไม่สำเร็จ กรุณารีเฟรชก่อนเปิดแบรนด์</p>
      : profile.role === "admin" ? <p>บัญชีผู้ดูแลระบบไม่เปลี่ยนเป็นแบรนด์ กรุณาใช้บัญชีสมาชิกแยกสำหรับเดโมแบรนด์</p>
      : profile.role === "brand" && active ? <Link href="/brand" className="inline-block font-semibold text-emerald-800 underline">บัญชีแบรนด์พร้อมแล้ว ไปจัดการแคมเปญ</Link>
      : <form action={openBrandAction} className="space-y-5">
        <label className="block font-semibold">ชื่อแบรนด์<input name="brandName" required minLength={2} maxLength={120} autoComplete="organization" defaultValue={typeof draft?.brand_name === "string" ? draft.brand_name.slice(0, 120) : ""} className={inputClass}/></label>
        <label className="block font-semibold">รายละเอียดแบรนด์<textarea name="brandDescription" required minLength={2} maxLength={2000} rows={4} defaultValue={typeof draft?.brand_description === "string" ? draft.brand_description.slice(0, 2000) : ""} className={inputClass}/></label>
        <label className="flex items-start gap-3 text-sm"><input type="checkbox" name="confirmPrototype" value="yes" required className="mt-1"/><span>ยืนยันเปิดแบรนด์สำหรับ prototype และรับสิทธิ์เจ้าของแบรนด์นี้</span></label>
        <PendingSubmitButton pendingLabel="กำลังเปิดแบรนด์…">ยืนยันเปิดบัญชีแบรนด์</PendingSubmitButton>
      </form>}
    <Link href="/profile" className="block text-sm text-emerald-800 underline">กลับโปรไฟล์</Link>
  </Card></Container>;
}
