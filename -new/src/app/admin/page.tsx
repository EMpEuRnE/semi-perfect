import { CheckCircle2, ClipboardCheck, XCircle } from "lucide-react";
import { reviewMissionActivityAction } from "@/app/actions/missions";
import { EmptyState, Notice } from "@/components/core/notice";
import { Card } from "@/components/ui/card";
import { Container } from "@/components/ui/container";
import { PageHeading } from "@/components/ui/page-heading";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { getSupabasePublicConfig } from "@/lib/env";
import type { Mission } from "@/lib/missions/data";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type AdminPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

type PendingActivity = {
  id: string;
  user_id: string;
  user_mission_id: string;
  activity_type: string;
  value: number;
  unit: string;
  evidence_url: string | null;
  evidence_notes: string | null;
  created_at: string;
};

function safeEvidenceUrl(value: string | null) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:" ? url.href : null;
  } catch {
    return null;
  }
}

export default async function AdminPage({ searchParams }: AdminPageProps) {
  const query = await searchParams;
  const errorCode = typeof query?.error === "string" ? query.error : undefined;
  const reviewed = typeof query?.reviewed === "string" ? query.reviewed : undefined;

  if (!getSupabasePublicConfig()) {
    return (
      <Container className="py-10 sm:py-14">
        <PageHeading eyebrow="ADMIN · INTERNAL" title="ตรวจผลกิจกรรมภารกิจ" description="ตรวจหลักฐานที่ผู้ใช้ส่งก่อนอนุมัติ progress และแต้ม" />
        <div className="mt-6"><Notice tone="error" title="ยังเชื่อมต่อ Supabase ไม่ได้">ตรวจสอบการตั้งค่าสภาพแวดล้อมสำหรับพัฒนา</Notice></div>
      </Container>
    );
  }

  const supabase = await createClient();
  const { data: activityRows, error } = await supabase
    .from("activities")
    .select("id,user_id,user_mission_id,activity_type,value,unit,evidence_url,evidence_notes,created_at")
    .eq("verification_status", "pending")
    .not("user_mission_id", "is", null)
    .order("created_at", { ascending: true })
    .limit(100);

  if (error) {
    return (
      <Container className="py-10 sm:py-14">
        <PageHeading eyebrow="ADMIN · INTERNAL" title="ตรวจผลกิจกรรมภารกิจ" description="ตรวจหลักฐานที่ผู้ใช้ส่งก่อนอนุมัติ progress และแต้ม" />
        <div className="mt-6"><Notice tone="error" title="โหลดรายการตรวจสอบไม่สำเร็จ">ยืนยันสิทธิ์ admin และลองโหลดหน้านี้อีกครั้ง</Notice></div>
      </Container>
    );
  }

  const activities = (activityRows ?? []) as unknown as PendingActivity[];
  const participationIds = [...new Set(activities.map((activity) => activity.user_mission_id))];
  const userIds = [...new Set(activities.map((activity) => activity.user_id))];
  const participationById = new Map<string, { mission_id: string; participation_date: string | null; mission_snapshot: Mission | null }>();
  const missionById = new Map<string, { title: string; points: number; target_value: number; target_unit: string }>();
  const profileById = new Map<string, { display_name: string | null }>();

  if (participationIds.length > 0) {
    const { data, error: participationError } = await supabase
      .from("user_missions")
      .select("id,mission_id,participation_date,mission_snapshot")
      .in("id", participationIds);
    if (participationError) {
      return (
        <Container className="py-10 sm:py-14">
          <PageHeading eyebrow="ADMIN · INTERNAL" title="ตรวจผลกิจกรรมภารกิจ" description="ตรวจหลักฐานที่ผู้ใช้ส่งก่อนอนุมัติ progress และแต้ม" />
          <div className="mt-6"><Notice tone="error">โหลดข้อมูลภารกิจไม่สำเร็จ</Notice></div>
        </Container>
      );
    }
    for (const row of (data ?? []) as Array<{ id: string; mission_id: string; participation_date: string | null; mission_snapshot: Mission | null }>) {
      participationById.set(row.id, row);
    }
  }

  const missionIds = [...new Set([...participationById.values()].map((row) => row.mission_id))];
  if (missionIds.length > 0) {
    const { data, error: missionError } = await supabase
      .from("missions")
      .select("id,title,points,target_value,target_unit")
      .in("id", missionIds);
    if (missionError) {
      return (
        <Container className="py-10 sm:py-14">
          <PageHeading eyebrow="ADMIN · INTERNAL" title="ตรวจผลกิจกรรมภารกิจ" description="ตรวจหลักฐานที่ผู้ใช้ส่งก่อนอนุมัติ progress และแต้ม" />
          <div className="mt-6"><Notice tone="error">โหลดข้อมูลภารกิจไม่สำเร็จ</Notice></div>
        </Container>
      );
    }
    for (const row of (data ?? []) as Array<{ id: string; title: string; points: number; target_value: number; target_unit: string }>) {
      missionById.set(row.id, row);
    }
  }

  if (userIds.length > 0) {
    const { data, error: profileError } = await supabase
      .from("profiles")
      .select("id,display_name")
      .in("id", userIds);
    if (profileError) {
      return (
        <Container className="py-10 sm:py-14">
          <PageHeading eyebrow="ADMIN · INTERNAL" title="ตรวจผลกิจกรรมภารกิจ" description="ตรวจหลักฐานที่ผู้ใช้ส่งก่อนอนุมัติ progress และแต้ม" />
          <div className="mt-6"><Notice tone="error">โหลดข้อมูลบัญชีผู้ใช้ไม่สำเร็จ</Notice></div>
        </Container>
      );
    }
    for (const row of (data ?? []) as Array<{ id: string; display_name: string | null }>) {
      profileById.set(row.id, row);
    }
  }

  return (
    <Container className="py-10 sm:py-14">
      <PageHeading eyebrow="ADMIN · INTERNAL" title="ตรวจผลกิจกรรมภารกิจ" description="ตรวจหลักฐานที่ผู้ใช้ส่งก่อนอนุมัติความคืบหน้าและแต้ม ทุกการตัดสินใจถูกบันทึกโดยฐานข้อมูล" />

      {errorCode ? <div className="mt-6"><Notice tone="error">ตรวจรายการไม่สำเร็จ กรุณาระบุเหตุผลอย่างน้อย 2 ตัวอักษรเมื่อไม่ผ่าน หรืออาจมีผู้ดูแลคนอื่นตรวจไปแล้ว</Notice></div> : null}
      {reviewed === "approved" ? <div className="mt-6"><Notice tone="success" title="อนุมัติผลกิจกรรมแล้ว">หากภารกิจครบเป้าหมาย แต้มจะอยู่ใน ledger และกระเป๋าของผู้ใช้</Notice></div> : null}
      {reviewed === "rejected" ? <div className="mt-6"><Notice tone="info" title="ปฏิเสธผลกิจกรรมแล้ว">บันทึกการตรวจสอบและหมายเหตุถูกส่งกลับไปยังประวัติของผู้ใช้</Notice></div> : null}

      <section className="mt-8">
        <div className="mb-4 flex items-end justify-between gap-4">
          <div>
            <h2 className="text-xl font-semibold text-slate-950">รายการรอตรวจสอบ</h2>
            <p className="mt-1 text-sm text-slate-600">{activities.length} รายการที่ส่งแล้วและยังไม่มีคำตัดสิน</p>
          </div>
          <ClipboardCheck size={24} className="text-emerald-700" aria-hidden="true" />
        </div>

        {activities.length === 0 ? (
          <EmptyState title="ไม่มีรายการรอตรวจสอบ">เมื่อผู้ใช้ส่งผลภารกิจ รายการจะปรากฏที่นี่</EmptyState>
        ) : (
          <div className="space-y-4">
            {activities.map((activity) => {
              const missionId = participationById.get(activity.user_mission_id)?.mission_id ?? "";
              const round = participationById.get(activity.user_mission_id);
              const mission = round?.mission_snapshot ?? missionById.get(missionId);
              const displayName = profileById.get(activity.user_id)?.display_name ?? "สมาชิก Move & Earn";
              const evidenceHref = safeEvidenceUrl(activity.evidence_url);

              return (
                <Card key={activity.id} className="p-5 sm:p-6">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-wide text-emerald-700">{displayName}</p>
                      <h3 className="mt-1 text-lg font-semibold text-slate-950">{mission?.title ?? "ภารกิจ"}</h3>
                      {round?.participation_date && <p className="mt-2 text-sm text-emerald-800">รอบวันที่ {round.participation_date} (เวลาไทย) — แต้มผูกกับรอบนี้ แม้ตรวจวันถัดไป</p>}
                      <p className="mt-2 text-sm text-slate-600">
                        ส่งผล {new Intl.NumberFormat("th-TH", { maximumFractionDigits: 3 }).format(Number(activity.value))} {activity.unit} · เป้าหมาย {mission ? `${new Intl.NumberFormat("th-TH").format(Number(mission.target_value))} ${mission.target_unit}` : "-"}
                      </p>
                      <p className="mt-1 text-xs text-slate-500">รับ {mission ? new Intl.NumberFormat("th-TH").format(Number(mission.points)) : "-"} แต้มเมื่อทำครบและอนุมัติ</p>
                    </div>
                    <p className="text-xs text-slate-500">{new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Bangkok" }).format(new Date(activity.created_at))}</p>
                  </div>

                  {activity.evidence_notes ? <p className="mt-4 whitespace-pre-wrap rounded-2xl bg-slate-50 p-4 text-sm leading-6 text-slate-700">{activity.evidence_notes}</p> : null}
                  {evidenceHref ? <a href={evidenceHref} target="_blank" rel="noreferrer" className="mt-3 inline-block break-all text-sm font-semibold text-emerald-800 underline">เปิดหลักฐานที่แนบมา</a> : null}

                  <form action={reviewMissionActivityAction} className="mt-5 border-t border-slate-100 pt-4">
                    <input type="hidden" name="activityId" value={activity.id} />
                    <input type="hidden" name="missionId" value={missionId} />
                    <label className="block space-y-2 text-sm font-semibold text-slate-700">
                      หมายเหตุถึงผู้ใช้ (ต้องระบุอย่างน้อย 2 ตัวอักษรเมื่อไม่ผ่าน)
                      <textarea name="reviewerNote" maxLength={1000} rows={2} className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 font-normal outline-none transition focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100" />
                    </label>
                    <div className="mt-4 flex flex-wrap gap-3">
                      <PendingSubmitButton name="approved" value="true" pendingLabel="กำลังอนุมัติ...">
                        <CheckCircle2 size={16} aria-hidden="true" /> อนุมัติ
                      </PendingSubmitButton>
                      <PendingSubmitButton name="approved" value="false" variant="secondary" pendingLabel="กำลังบันทึก...">
                        <XCircle size={16} aria-hidden="true" /> ปฏิเสธ
                      </PendingSubmitButton>
                    </div>
                  </form>
                </Card>
              );
            })}
          </div>
        )}
      </section>
    </Container>
  );
}
