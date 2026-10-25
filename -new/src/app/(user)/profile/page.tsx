import { requireAuthenticatedUser } from "@/lib/auth/guards";
import { getUserProfile } from "@/lib/auth/session";
import Link from "next/link";
import { hasActiveBrandMembership } from "@/lib/auth/brand-access";
import { updateProfileAction, signOutAction } from "@/app/actions/auth";
import { Container } from "@/components/ui/container";
import { Card } from "@/components/ui/card";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";

export const dynamic = "force-dynamic";

type ProfilePageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

const errorMessages: Record<string, string> = {
  setup: "ยังไม่ได้เชื่อมต่อ Supabase โปรดตรวจสอบการตั้งค่า",
  "invalid-profile": "กรุณากรอกชื่อที่แสดงไม่เกิน 80 ตัวอักษร",
  "profile-save": "บันทึกโปรไฟล์ไม่สำเร็จ โปรดลองอีกครั้ง",
  logout: "ออกจากระบบไม่สำเร็จ โปรดลองอีกครั้ง",
};

const roleLabels = {
  user: "ผู้ใช้",
  brand: "แบรนด์",
  admin: "ผู้ดูแลระบบ",
} as const;

export default async function ProfilePage({ searchParams }: ProfilePageProps) {
  const user = await requireAuthenticatedUser("/profile");
  const profile = await getUserProfile(user.id);
  const brandAccess = profile?.role === "brand" && await hasActiveBrandMembership(user.id);
  const params = await searchParams;
  const errorCode = typeof params?.error === "string" ? params.error : undefined;
  const messageCode = typeof params?.message === "string" ? params.message : undefined;

  if (!profile) {
    return (
      <Container className="py-12 sm:py-16">
        <Card className="mx-auto max-w-2xl p-6 sm:p-9">
          <h1 className="text-2xl font-semibold text-slate-950">ยังโหลดโปรไฟล์ไม่ได้</h1>
          <p className="mt-3 text-sm leading-6 text-slate-600">
            โปรไฟล์จะถูกสร้างโดยฐานข้อมูลเมื่อสมัครสมาชิก หากเพิ่งตั้งค่า Supabase ให้ตรวจว่า migration ถูกนำไปใช้แล้ว
          </p>
        </Card>
      </Container>
    );
  }

  const createdAt = new Intl.DateTimeFormat("th-TH", { dateStyle: "long" }).format(new Date(profile.createdAt));

  return (
    <Container className="py-10 sm:py-14">
      <div className="mx-auto max-w-3xl">
        <p className="text-xs font-bold uppercase tracking-[0.16em] text-emerald-700">บัญชีของฉัน</p>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight text-slate-950">โปรไฟล์</h1>
        <p className="mt-2 text-sm leading-6 text-slate-600">ข้อมูลบัญชีของคุณและสิทธิ์ที่กำหนดโดย Move & Earn</p>

        {errorCode ? (
          <p role="alert" className="mt-6 rounded-2xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800">
            {errorMessages[errorCode] ?? "ดำเนินการไม่สำเร็จ โปรดลองอีกครั้ง"}
          </p>
        ) : null}
        {messageCode === "profile-saved" ? (
          <p role="status" className="mt-6 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-900">
            บันทึกโปรไฟล์แล้ว
          </p>
        ) : null}

        <div className="mt-7 grid gap-5 md:grid-cols-[0.8fr_1.2fr]">
          <Card className="p-6">
            <div className="flex size-14 items-center justify-center rounded-2xl bg-emerald-50 text-xl font-semibold text-emerald-800" aria-hidden="true">
              {(profile.displayName ?? profile.email ?? "M").slice(0, 1).toUpperCase()}
            </div>
            <h2 className="mt-4 text-lg font-semibold text-slate-950">{profile.displayName ?? "สมาชิก Move & Earn"}</h2>
            <p className="mt-1 break-all text-sm text-slate-600">{profile.email ?? "ไม่พบอีเมลในบัญชี"}</p>
            <div className="mt-5 border-t border-slate-100 pt-4">
              <p className="text-xs font-medium text-slate-500">ประเภทบัญชี</p>
              <p className="mt-1 text-sm font-semibold text-slate-800">{roleLabels[profile.role]}{profile.role === "brand" && !brandAccess ? " (ยังไม่มีสมาชิกแบรนด์ที่เปิดใช้งาน)" : ""}</p>
              {profile.role !== "admin" && <Link href={brandAccess ? "/brand" : "/open-brand"} className="mt-4 inline-block font-semibold text-emerald-800 underline">{brandAccess ? "จัดการแบรนด์ของฉัน" : "เปิดบัญชีแบรนด์ด้วยบัญชีนี้"}</Link>}
              <p className="mt-4 text-xs font-medium text-slate-500">สมัครเมื่อ</p>
              <p className="mt-1 text-sm text-slate-700">{createdAt}</p>
            </div>
          </Card>

          <Card className="p-6 sm:p-7">
            <h2 className="text-lg font-semibold text-slate-950">ข้อมูลส่วนตัว</h2>
            <p className="mt-1 text-sm leading-6 text-slate-600">แก้ไขชื่อที่แสดงได้ หากต้องการสร้างแคมเปญให้เปิดบัญชีแบรนด์โดยเก็บประวัติเดิมไว้</p>
            <form action={updateProfileAction} className="mt-5 space-y-4">
              <label className="block space-y-2 text-sm font-semibold text-slate-700">
                ชื่อที่แสดง
                <input
                  name="displayName"
                  type="text"
                  autoComplete="name"
                  required
                  maxLength={80}
                  defaultValue={profile.displayName ?? ""}
                  className="min-h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 font-normal outline-none transition focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100"
                />
              </label>
              <PendingSubmitButton pendingLabel="กำลังบันทึก...">บันทึกการเปลี่ยนแปลง</PendingSubmitButton>
            </form>
          </Card>
        </div>

        <form action={signOutAction} className="mt-5">
          <PendingSubmitButton variant="secondary" pendingLabel="กำลังออกจากระบบ...">ออกจากระบบ</PendingSubmitButton>
        </form>
      </div>
    </Container>
  );
}
