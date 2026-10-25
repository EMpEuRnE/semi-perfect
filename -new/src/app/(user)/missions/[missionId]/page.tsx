import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, ArrowRight, CheckCircle2, LockKeyhole, Sparkles } from "lucide-react";
import { joinMissionAction } from "@/app/actions/missions";
import { ActivityList } from "@/components/missions/activity-list";
import { MissionActivityForm } from "@/components/missions/mission-activity-form";
import { Notice } from "@/components/core/notice";
import { ProgressBar } from "@/components/core/progress-bar";
import { Card } from "@/components/ui/card";
import { Container } from "@/components/ui/container";
import { PageHeading } from "@/components/ui/page-heading";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { getAuthenticatedUser } from "@/lib/auth/session";
import { difficultyLabels, roundStatus } from "@/lib/mission-rounds";
import { getMissionDetail } from "@/lib/missions/data";

export const dynamic = "force-dynamic";

type MissionDetailProps = {
  params: Promise<{ missionId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const numbers = new Intl.NumberFormat("th-TH", { maximumFractionDigits: 3 });

const errors: Record<string, string> = {
  setup: "ยังไม่ได้เชื่อมต่อ Supabase สำหรับสภาพแวดล้อมนี้",
  join: "เริ่มภารกิจไม่สำเร็จ โปรดลองอีกครั้ง",
  "invalid-activity": "ตรวจสอบค่ากิจกรรม ลิงก์หลักฐาน และบันทึก แล้วลองใหม่",
  pending: "มีผลกิจกรรมของภารกิจนี้รอตรวจสอบอยู่แล้ว",
  "evidence-required": "ภารกิจนี้ต้องส่งลิงก์หรือบันทึกหลักฐาน",
  activity: "ส่งกิจกรรมไม่สำเร็จ ตรวจสอบชนิดกิจกรรม เป้าหมาย และรอบวัน หากข้ามเที่ยงคืนให้เริ่มรอบวันนี้แทน",
};

export default async function MissionDetailPage({ params, searchParams }: MissionDetailProps) {
  const [{ missionId }, user, query] = await Promise.all([
    params,
    getAuthenticatedUser(),
    searchParams,
  ]);
  if (!uuidPattern.test(missionId)) notFound();

  const state = await getMissionDetail(missionId, user?.id ?? null, typeof query?.day === "string" ? query.day : undefined);
  if (state.status === "setup") {
    return <Container className="py-10 sm:py-14"><Notice tone="error" title="ยังเชื่อมต่อฐานข้อมูลไม่ได้">ตรวจสอบการตั้งค่า Supabase สำหรับการพัฒนา</Notice></Container>;
  }
  if (state.status === "error") {
    return <Container className="py-10 sm:py-14"><Notice tone="error" title="โหลดรายละเอียดไม่สำเร็จ">โปรดลองเปิดภารกิจนี้อีกครั้ง</Notice></Container>;
  }
  if (!state.data) notFound();
  const detail = state.data;
  const pastRound = Boolean(detail.roundDay && detail.roundDay !== detail.today);

  const errorCode = typeof query?.error === "string" ? query.error : undefined;
  const joined = query?.joined === "1";
  const submitted = query?.submitted === "1";

  return (
    <Container className="py-10 sm:py-14">
      <Link href="/missions" className="mb-6 inline-flex items-center gap-2 text-sm font-semibold text-emerald-800 hover:underline">
        <ArrowLeft size={16} aria-hidden="true" /> กลับไปดูภารกิจ
      </Link>

      <PageHeading
        eyebrow="รายละเอียดภารกิจ"
        title={detail.mission.title}
        description={detail.mission.description}
      />

      <Card className="mt-6 space-y-3 p-5">
        <p className="font-semibold text-emerald-800">ความยาก: {difficultyLabels[detail.mission.difficulty]} · {detail.mission.recurrence === "daily" ? `รอบวันที่ ${detail.roundDay} (เวลาไทย)` : "ภารกิจทั่วไป"}</p>
        <p className="whitespace-pre-wrap break-words text-sm">เงื่อนไข: {detail.mission.participation_terms}</p>
        {detail.mission.recurrence === "daily" && <p className="text-sm text-slate-600">ทำได้วันละหนึ่งรอบ ส่งผลภายใน 00:00–23:59 น. เวลาไทย รายการที่ส่งทันเวลายังอนุมัติภายหลังได้ โดยแต้มเป็นของรอบเดิม</p>}
      </Card>

          {errorCode ? <div className="mt-6"><Notice tone="error">{errors[errorCode] ?? "ดำเนินการไม่สำเร็จ โปรดลองอีกครั้ง"}</Notice></div> : null}
          {joined ? <div className="mt-6"><Notice tone="success" title="เริ่มภารกิจแล้ว">ทำกิจกรรมตามเป้าหมาย แล้วส่งผลให้ผู้ดูแลตรวจสอบ</Notice></div> : null}
          {submitted ? <div className="mt-6"><Notice tone="success" title="ส่งผลกิจกรรมแล้ว">รายการของคุณอยู่ในสถานะรอตรวจสอบ แต้มจะเข้ากระเป๋าหลังภารกิจผ่านการตรวจ</Notice></div> : null}

          <div className="mt-8 grid gap-5 lg:grid-cols-[1.1fr_0.9fr]">
            <div className="space-y-5">
              <Card className="p-5 sm:p-7">
                <div className="flex flex-wrap items-center justify-between gap-4">
                  <div>
                    <p className="text-sm font-medium text-slate-500">เป้าหมายกิจกรรม</p>
                    <p className="mt-1 text-2xl font-semibold text-slate-950">
                      {numbers.format(Number(detail.mission.target_value))} {detail.mission.target_unit}
                    </p>
                  </div>
                  <div className="flex items-center gap-2 rounded-2xl bg-lime-50 px-4 py-3 font-semibold text-emerald-900">
                    <Sparkles size={18} aria-hidden="true" /> {numbers.format(detail.mission.points)} แต้มเมื่อสำเร็จ
                  </div>
                </div>
                <div className="mt-6 grid gap-3 text-sm text-slate-600 sm:grid-cols-2">
                  <p>รูปแบบกิจกรรม: <span className="font-semibold text-slate-800">{detail.mission.activity_type}</span></p>
                  <p>หลักฐาน: <span className="font-semibold text-slate-800">{detail.mission.requires_evidence ? "จำเป็น" : "ไม่บังคับ"}</span></p>
                </div>
                {detail.participation ? (
                  <div className="mt-6 border-t border-slate-100 pt-5">
                    <p className="mb-3 text-sm font-semibold">{roundStatus(detail.participation)}</p>
                    <p className="mb-2 text-sm">ความคืบหน้าที่อนุมัติแล้ว</p>
                    <ProgressBar
                      value={Number(detail.participation.progress_value)}
                      target={Number(detail.mission.target_value)}
                      unit={detail.mission.target_unit}
                    />
                    <p className="mt-3 text-sm text-slate-600">ส่งทั้งหมด {numbers.format(Number(detail.participation.reported_value ?? 0))} {detail.mission.target_unit} (รวมรายการไม่ผ่านและส่งซ้ำ)</p>
                    <p className="mt-1 text-sm text-amber-800">รอตรวจ {numbers.format(Number(detail.participation.pending_value ?? 0))} {detail.mission.target_unit} — ยังไม่นับเป็นความคืบหน้าหรือแต้ม</p>
                  </div>
                ) : null}
              </Card>

              {detail.participation?.status === "completed" ? (
                <Notice tone="success" title="ทำภารกิจสำเร็จแล้ว">
                  {detail.mission.recurrence === "daily" ? "รอบนี้ได้รับแต้มแล้ว รับได้ครั้งเดียวต่อรอบวัน " : ""}แต้มจากภารกิจนี้บันทึกในบัญชีแต้มและตรวจสอบได้ที่ <Link href="/wallet" className="font-semibold underline">กระเป๋าแต้ม</Link>
                </Notice>
              ) : pastRound ? (
                <Notice tone="info" title="รอบวันที่เลือกสิ้นสุดแล้ว">ส่งกิจกรรมเพิ่มในรอบเก่าไม่ได้ แต่หลักฐานที่ส่งทันเวลายังรอตรวจได้ <Link href={`/missions/${missionId}`} className="font-semibold underline">ไปเริ่มรอบวันนี้</Link></Notice>
              ) : detail.participation?.status === "cancelled" || detail.participation?.status === "expired" ? (
                <Notice tone="info" title="ภารกิจนี้ไม่รับผลกิจกรรมเพิ่มแล้ว">ดูรายการที่ส่งไปก่อนหน้าได้จากประวัติภารกิจด้านล่าง</Notice>
              ) : detail.participation ? (
                <MissionActivityForm
                  mission={detail.mission}
                  participation={detail.participation}
                  pending={detail.activities.some((activity) => activity.verification_status === "pending")}
                />
              ) : user ? (
                <Card className="flex flex-col items-start gap-4 p-5 sm:flex-row sm:items-center sm:justify-between sm:p-6">
                  <div>
                    <h2 className="text-lg font-semibold text-slate-950">พร้อมเริ่มหรือยัง?</h2>
                    <p className="mt-1 text-sm text-slate-600">เริ่มภารกิจเพื่อบันทึกความคืบหน้าไว้ในบัญชีของคุณ</p>
                  </div>
                  <form action={joinMissionAction}>
                    <input type="hidden" name="missionId" value={detail.mission.id} />
                    <PendingSubmitButton pendingLabel="กำลังเริ่มภารกิจ...">
                      เริ่มภารกิจ <ArrowRight size={16} aria-hidden="true" />
                    </PendingSubmitButton>
                  </form>
                </Card>
              ) : (
                <Card className="flex flex-col items-start gap-4 p-5 sm:flex-row sm:items-center sm:justify-between sm:p-6">
                  <div className="flex items-start gap-3">
                    <LockKeyhole size={20} className="mt-0.5 shrink-0 text-emerald-800" aria-hidden="true" />
                    <div>
                      <h2 className="font-semibold text-slate-950">เข้าสู่ระบบเพื่อเริ่มภารกิจ</h2>
                      <p className="mt-1 text-sm text-slate-600">ผลกิจกรรมและแต้มจะผูกกับบัญชีของคุณ</p>
                    </div>
                  </div>
                  <Link href={`/login?next=${encodeURIComponent(`/missions/${missionId}`)}`} className="inline-flex min-h-11 items-center justify-center gap-2 rounded-full bg-emerald-700 px-5 py-2.5 text-sm font-semibold text-white hover:bg-emerald-800">
                    เข้าสู่ระบบ <ArrowRight size={16} aria-hidden="true" />
                  </Link>
                </Card>
              )}
            </div>

            <Card className="p-5 sm:p-6">
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-lg font-semibold text-slate-950">ประวัติผลกิจกรรม</h2>
                {detail.participation?.status === "completed" ? <CheckCircle2 className="text-emerald-700" aria-label="ภารกิจสำเร็จ" /> : null}
              </div>
              {detail.participation ? (
                <ActivityList activities={detail.activities} />
              ) : (
                <p className="mt-4 text-sm leading-6 text-slate-600">เริ่มภารกิจก่อน แล้วรายการที่ส่งให้ตรวจสอบจะแสดงที่นี่</p>
              )}
            </Card>
          </div>
    </Container>
  );
}
