import Link from "next/link";
import { ArrowLeft, MoveRight } from "lucide-react";
import { Container } from "@/components/ui/container";
import { Card } from "@/components/ui/card";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { signInAction, signUpAction } from "@/app/actions/auth";
import { getSupabasePublicConfig } from "@/lib/env";

type AuthCardProps = {
  mode: "login" | "register";
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

const errorMessages: Record<string, string> = {
  setup: "ยังไม่ได้เชื่อมต่อ Supabase โปรดตั้งค่าในไฟล์ .env.local ก่อน",
  credentials: "อีเมลหรือรหัสผ่านไม่ถูกต้อง โปรดลองอีกครั้ง",
  network: "ติดต่อระบบสมัครไม่ได้ กรุณาตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง",
  "rate-limit": "ส่งคำขอหรืออีเมลยืนยันถี่เกินไป กรุณารอสักครู่ก่อนลองใหม่ และตรวจกล่องจดหมายรวมถึงสแปม",
  email: "ระบบไม่รับอีเมลนี้ กรุณาตรวจอีเมล หรือติดต่อผู้ดูแลตรวจการตั้งค่าการส่งอีเมล",
  password: "รหัสผ่านไม่ผ่านเงื่อนไขความปลอดภัย กรุณาใช้รหัสผ่านที่ยาวขึ้นและผสมตัวอักษรกับตัวเลข",
  "signup-disabled": "ระบบปิดการสมัครด้วยอีเมลอยู่ กรุณาให้ผู้ดูแลตรวจ Supabase Auth",
  "existing-account": "สมัครด้วยอีเมลนี้ไม่ได้ หากมีบัญชีแล้วให้เข้าสู่ระบบ แล้วเปิดบัญชีแบรนด์จากโปรไฟล์",
  "auth-service": "บริการ Auth สร้างบัญชีไม่สำเร็จ ผู้ดูแลต้องตรวจ Auth logs และ trigger สร้างโปรไฟล์ก่อนลองใหม่",
  signup: "สมัครสมาชิกไม่สำเร็จ โปรดลองใหม่หรือตรวจสอบการตั้งค่า Supabase Auth",
  "invalid-input": "กรอกชื่อ อีเมล และรหัสผ่านอย่างน้อย 8 ตัวอักษรให้ครบถ้วน",
  "invalid-brand": "กรุณากรอกชื่อแบรนด์ 2–120 ตัวอักษร และรายละเอียด 2–2,000 ตัวอักษร",
  "brand-access": "บัญชีนี้ยังไม่มีสิทธิ์สำหรับพื้นที่แบรนด์",
  "admin-access": "บัญชีนี้ยังไม่มีสิทธิ์ผู้ดูแลระบบ",
  "auth-callback": "ยืนยันอีเมลไม่สำเร็จ ให้เปิดลิงก์ล่าสุดในเบราว์เซอร์เดียวกับที่สมัคร หากยืนยันแล้วให้ลองเข้าสู่ระบบ ไม่ต้องสมัครซ้ำ",
  profile: "ยังโหลดข้อมูลบัญชีไม่ได้ โปรดลองอีกครั้ง",
  logout: "ออกจากระบบไม่สำเร็จ โปรดลองอีกครั้ง",
};

export async function AuthCard({ mode, searchParams }: AuthCardProps) {
  const params = await searchParams;
  const errorCode = typeof params?.error === "string" ? params.error : undefined;
  const messageCode = typeof params?.message === "string" ? params.message : undefined;
  const nextPath = typeof params?.next === "string" ? params.next : undefined;
  const isRegister = mode === "register";
  const isBrand = isRegister && params?.account === "brand";
  const isConfigured = Boolean(getSupabasePublicConfig());
  const error = errorCode
    ? errorMessages[errorCode] ?? "ดำเนินการไม่สำเร็จ โปรดลองอีกครั้ง"
    : isConfigured
      ? undefined
      : errorMessages.setup;
  const notice = messageCode === "check-email" ? "ส่งลิงก์ยืนยันไปที่อีเมลแล้ว โปรดตรวจกล่องจดหมายและสแปม เปิดลิงก์ในเบราว์เซอร์เดียวกับที่สมัคร จากนั้นเข้าสู่ระบบเพื่อทำขั้นตอนต่อ" : messageCode === "existing-account" ? "หากมีบัญชีอีเมลนี้แล้ว ให้เข้าสู่ระบบเพื่อเปิดแบรนด์ด้วยบัญชีเดิม ประวัติและแต้มเดิมจะยังอยู่" : undefined;

  return (
    <Container className="grid min-h-[calc(100svh-76px)] items-center gap-10 py-10 lg:grid-cols-[1fr_0.9fr] lg:py-16">
      <div className="hidden max-w-xl lg:block">
        <Link href="/" className="mb-10 inline-flex items-center gap-2 text-sm font-medium text-slate-500 hover:text-slate-900">
          <ArrowLeft size={16} aria-hidden="true" /> กลับหน้าแรก
        </Link>
        <div className="mb-5 inline-flex items-center gap-2 rounded-full bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-800">
          <MoveRight size={14} aria-hidden="true" /> Mission → Activity → Reward
        </div>
        <h1 className="text-5xl font-semibold leading-[1.1] tracking-tight text-slate-950">
          ขยับอีกนิด<br /><span className="text-emerald-700">รับสิ่งดี ๆ กลับมา</span>
        </h1>
        <p className="mt-5 max-w-md text-lg leading-8 text-slate-600">
          สร้างกิจวัตรที่ดีไปพร้อมกับภารกิจและรางวัลจากแบรนด์ที่คุณชอบ
        </p>
      </div>

      <Card className="mx-auto w-full max-w-lg p-6 sm:p-9">
        <div className="mb-7">
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-emerald-700">บัญชี Move & Earn</p>
          <h2 className="mt-3 text-3xl font-semibold tracking-tight text-slate-950">
            {isRegister ? isBrand ? "สมัครบัญชีแบรนด์" : "สร้างบัญชีผู้ใช้" : "ยินดีต้อนรับกลับ"}
          </h2>
          <p className="mt-2 text-sm leading-6 text-slate-600">
            {isRegister ? "เริ่มสะสมแต้มจากการทำสิ่งที่ดีให้ตัวเอง" : "เข้าสู่ระบบเพื่อไปต่อกับภารกิจของคุณ"}
          </p>
        </div>

        {error ? <p role="alert" className="mb-5 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">{error}</p> : null}
        {notice ? <p role="status" className="mb-5 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900">{notice}</p> : null}

        {isRegister && <nav aria-label="ประเภทบัญชีที่สมัคร" className="mb-5 flex flex-wrap gap-3">
          <Link href="/register" aria-current={!isBrand ? "page" : undefined} className={`rounded-xl border px-4 py-3 text-sm ${!isBrand ? "bg-emerald-700 text-white" : "text-emerald-800"}`}>สมัครผู้ใช้</Link>
          <Link href="/register?account=brand" aria-current={isBrand ? "page" : undefined} className={`rounded-xl border px-4 py-3 text-sm ${isBrand ? "bg-emerald-700 text-white" : "text-emerald-800"}`}>สมัครแบรนด์</Link>
        </nav>}

        <form action={isRegister ? signUpAction : signInAction} className="space-y-4">
          {isRegister && <input type="hidden" name="accountType" value={isBrand ? "brand" : "user"}/>}
          {isRegister ? (
            <label className="block space-y-2 text-sm font-semibold text-slate-700">
              ชื่อที่แสดง
              <input name="fullName" type="text" autoComplete="name" required maxLength={80} className="min-h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 font-normal outline-none transition focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100" />
            </label>
          ) : null}
          {isBrand && <>
            <label className="block space-y-2 text-sm font-semibold text-slate-700">ชื่อแบรนด์<input name="brandName" autoComplete="organization" required minLength={2} maxLength={120} className="min-h-12 w-full rounded-2xl border border-slate-200 p-3 font-normal"/></label>
            <label className="block space-y-2 text-sm font-semibold text-slate-700">รายละเอียดแบรนด์<textarea name="brandDescription" required minLength={2} maxLength={2000} rows={3} className="w-full rounded-2xl border border-slate-200 p-3 font-normal"/></label>
            <p className="text-sm text-slate-600">หลังสมัครและเข้าสู่ระบบ ให้ยืนยันเปิดแบรนด์อีกครั้ง ระบบ prototype เปิดใช้งานทันที โดยไม่เปลี่ยนสิทธิ์ผู้ดูแลระบบ</p>
          </>}
          <label className="block space-y-2 text-sm font-semibold text-slate-700">
            อีเมล
            <input name="email" type="email" autoComplete="email" required maxLength={254} className="min-h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 font-normal outline-none transition focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100" />
          </label>
          <label className="block space-y-2 text-sm font-semibold text-slate-700">
            รหัสผ่าน
            <input name="password" type="password" autoComplete={isRegister ? "new-password" : "current-password"} required minLength={isRegister ? 8 : undefined} maxLength={128} className="min-h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 font-normal outline-none transition focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100" />
            {isRegister ? <span className="block text-xs font-normal text-slate-500">อย่างน้อย 8 ตัวอักษร</span> : null}
          </label>
          {!isRegister && nextPath ? <input type="hidden" name="next" value={nextPath} /> : null}
          <PendingSubmitButton className="mt-2 w-full" pendingLabel={isRegister ? "กำลังสมัครสมาชิก..." : "กำลังเข้าสู่ระบบ..."}>
            {isRegister ? "สมัครสมาชิก" : "เข้าสู่ระบบ"}
            <MoveRight size={17} aria-hidden="true" />
          </PendingSubmitButton>
        </form>

        <p className="mt-6 text-center text-sm text-slate-600">
          {isRegister ? "มีบัญชีอยู่แล้ว?" : "ยังไม่มีบัญชี?"}{" "}
          <Link href={isRegister ? isBrand ? "/login?next=%2Fopen-brand" : "/login" : "/register"} className="font-semibold text-emerald-800 underline-offset-4 hover:underline">
            {isRegister ? "เข้าสู่ระบบ" : "สมัครสมาชิก"}
          </Link>
        </p>
      </Card>
    </Container>
  );
}
