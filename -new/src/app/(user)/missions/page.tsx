import Link from "next/link";
import { ArrowRight, LogIn, Target } from "lucide-react";
import { getAuthenticatedUser } from "@/lib/auth/session";
import { getAvailableMissions } from "@/lib/missions/data";
import { MissionCard } from "@/components/missions/mission-card";
import { EmptyState, Notice } from "@/components/core/notice";
import { Container } from "@/components/ui/container";
import { PageHeading } from "@/components/ui/page-heading";
import { buttonLinkClass } from "@/components/ui/button";

export const dynamic = "force-dynamic";

type MissionsPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function MissionsPage({ searchParams }: MissionsPageProps) {
  const [user, params] = await Promise.all([getAuthenticatedUser(), searchParams]);
  const state = await getAvailableMissions(user?.id ?? null);
  const errorCode = typeof params?.error === "string" ? params.error : undefined;

  return (
    <Container className="py-10 sm:py-14">
      <PageHeading
        eyebrow="USER · MISSIONS"
        title="ภารกิจที่ทำได้วันนี้"
        description="เลือกภารกิจ ลงมือทำ แล้วส่งผลให้ผู้ดูแลตรวจสอบก่อนรับแต้มเข้าสู่กระเป๋าของคุณ"
      />

      <p className="mb-6 text-sm text-slate-600">ภารกิจรายวันเริ่มรอบใหม่เวลา 00:00 น. ตาม Asia/Bangkok ส่งหลักฐานภายในรอบวัน แต้มจะได้หลังตรวจผ่านเท่านั้น ดูรอบเก่าได้ในประวัติ</p>

      {!user ? (
        <Notice tone="info" title="เข้าสู่ระบบเพื่อบันทึกความคืบหน้า">
          คุณดูภารกิจได้โดยไม่ต้องเข้าสู่ระบบ แต่ต้องเข้าสู่ระบบก่อนเริ่มและส่งผลกิจกรรม
          <Link href="/login?next=%2Fmissions" className="ml-1 inline-flex items-center gap-1 font-semibold underline">
            <LogIn size={14} aria-hidden="true" /> เข้าสู่ระบบ
          </Link>
        </Notice>
      ) : null}

      {errorCode ? (
        <div className="mt-6"><Notice tone="error">ทำรายการไม่สำเร็จ โปรดลองอีกครั้ง</Notice></div>
      ) : null}

      {state.status === "setup" ? (
        <div className="mt-8"><Notice tone="error" title="ยังไม่ได้เชื่อมต่อฐานข้อมูล">ตรวจสอบการตั้งค่า Supabase ในไฟล์สภาพแวดล้อมสำหรับพัฒนา</Notice></div>
      ) : state.status === "error" ? (
        <div className="mt-8"><Notice tone="error" title="โหลดภารกิจไม่สำเร็จ">โปรดลองโหลดหน้านี้อีกครั้งในภายหลัง</Notice></div>
      ) : state.data.length === 0 ? (
        <div className="mt-8"><EmptyState title="ยังไม่มีภารกิจเปิดรับสมาชิก">ภารกิจใหม่จะแสดงที่นี่เมื่อพร้อมให้เริ่มทำ</EmptyState></div>
      ) : (
        <section aria-label="รายการภารกิจ" className="mt-8">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <p className="text-sm font-medium text-slate-600">พบ {state.data.length} ภารกิจ</p>
            {user ? (
              <Link href="/wallet" className={buttonLinkClass("secondary")}>
                <Target size={16} aria-hidden="true" /> ดูกระเป๋าแต้ม <ArrowRight size={15} aria-hidden="true" />
              </Link>
            ) : null}
          </div>
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {state.data.map(({ participation, ...mission }) => (
              <MissionCard key={mission.id} mission={mission} participation={participation} authenticated={Boolean(user)} />
            ))}
          </div>
        </section>
      )}
    </Container>
  );
}
