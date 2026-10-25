import Link from "next/link";
import { bangkokDay } from "@/lib/mission-rounds";
import { ArrowRight, Clock3 } from "lucide-react";
import { requireAuthenticatedUser } from "@/lib/auth/guards";
import { getHistoryData } from "@/lib/missions/data";
import { ActivityList } from "@/components/missions/activity-list";
import { EmptyState, Notice } from "@/components/core/notice";
import { PointTransactions } from "@/components/wallet/point-transactions";
import { Card } from "@/components/ui/card";
import { Container } from "@/components/ui/container";
import { PageHeading } from "@/components/ui/page-heading";

export const dynamic = "force-dynamic";

export default async function HistoryPage() {
  const user = await requireAuthenticatedUser("/history");
  const state = await getHistoryData(user.id);

  return (
    <Container className="py-10 sm:py-14">
      <PageHeading eyebrow="USER · HISTORY" title="ประวัติกิจกรรมและแต้ม" description="ติดตามผลที่ส่งให้ตรวจสอบ ความคืบหน้าภารกิจ และการเปลี่ยนแปลงในบัญชีแต้ม" />

      {state.status === "setup" ? (
        <div className="mt-8"><Notice tone="error" title="ยังเชื่อมต่อ Supabase ไม่ได้">ตรวจสอบการตั้งค่าสภาพแวดล้อมสำหรับพัฒนา</Notice></div>
      ) : state.status === "error" ? (
        <div className="mt-8"><Notice tone="error" title="โหลดประวัติไม่สำเร็จ">โปรดลองโหลดหน้านี้อีกครั้ง</Notice></div>
      ) : (
        <div className="mt-8 space-y-8">
          <section>
            <div className="mb-4 flex items-end justify-between gap-3">
              <div>
                <h2 className="text-xl font-semibold text-slate-950">ภารกิจของฉัน</h2>
                <p className="mt-1 text-sm text-slate-600">สถานะและผลที่ส่งให้ตรวจสอบ</p>
              </div>
              <Link href="/missions" className="inline-flex items-center gap-1 text-sm font-semibold text-emerald-800 hover:underline">ดูภารกิจ <ArrowRight size={15} aria-hidden="true" /></Link>
            </div>
            {state.data.missions.length === 0 ? (
              <EmptyState title="ยังไม่มีภารกิจที่เริ่มไว้">เลือกภารกิจแรกแล้วเริ่มสะสมความคืบหน้าได้ที่หน้า <Link href="/missions" className="font-semibold text-emerald-800 underline">ภารกิจ</Link></EmptyState>
            ) : (
              <div className="grid gap-4 md:grid-cols-2">
                {state.data.missions.map((mission) => (
                  <Card key={mission.id} className="p-5">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <Link href={`/missions/${mission.mission_id}${mission.participation_date ? `?day=${mission.participation_date}` : ""}`} className="font-semibold text-slate-950 hover:text-emerald-800 hover:underline">{mission.missionTitle}</Link>
                        {mission.participation_date && <p className="mt-1 text-xs text-emerald-800">รอบวันที่ {mission.participation_date} (เวลาไทย)</p>}
                        <p className="mt-1 text-xs text-slate-500">เริ่มเมื่อ {new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeZone: "Asia/Bangkok" }).format(new Date(mission.joined_at))}</p>
                      </div>
                      <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">{mission.status === "completed" ? "สำเร็จแล้ว" : mission.participation_date && mission.participation_date < bangkokDay() ? "รอบสิ้นสุดแล้ว / ดูผลตรวจ" : mission.status === "in_progress" ? "กำลังทำ" : mission.status === "joined" ? "เริ่มแล้ว" : mission.status === "expired" ? "หมดเวลา" : "ยกเลิกแล้ว"}</span>
                    </div>
                    <p className="mt-3 text-sm text-slate-600">ความคืบหน้า {new Intl.NumberFormat("th-TH", { maximumFractionDigits: 3 }).format(Number(mission.progress_value))}</p>
                  </Card>
                ))}
              </div>
            )}
          </section>

          <section>
            <h2 className="mb-4 text-xl font-semibold text-slate-950">ผลกิจกรรม</h2>
            {state.data.activities.length === 0 ? (
              <EmptyState title="ยังไม่มีผลกิจกรรมที่ส่ง">เมื่อส่งผลภารกิจ สถานะการตรวจสอบจะแสดงที่นี่</EmptyState>
            ) : (
              <div className="space-y-4">
                {state.data.activities.map((activity) => (
                  <Card key={activity.id} className="p-5">
                    <div className="mb-3 flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <p className="font-semibold text-slate-950">{activity.missionTitle}</p>
                        <p className="mt-1 text-sm text-slate-600">ส่งผล {new Intl.NumberFormat("th-TH", { maximumFractionDigits: 3 }).format(Number(activity.value))} {activity.unit}</p>
                      </div>
                      <span className="inline-flex items-center gap-1.5 text-xs font-medium text-slate-500"><Clock3 size={14} aria-hidden="true" /> {new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Bangkok" }).format(new Date(activity.created_at))}</span>
                    </div>
                    <ActivityList activities={[activity]} />
                  </Card>
                ))}
              </div>
            )}
          </section>

          <section>
            <h2 className="mb-4 text-xl font-semibold text-slate-950">ธุรกรรมแต้ม</h2>
            <Card className="p-5 sm:p-6">
              <PointTransactions transactions={state.data.transactions} emptyText="ยังไม่มีธุรกรรมแต้ม" />
            </Card>
          </section>
        </div>
      )}
    </Container>
  );
}
