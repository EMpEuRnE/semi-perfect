import { FileCheck2 } from "lucide-react";
import { submitMissionActivityAction } from "@/app/actions/missions";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { Card } from "@/components/ui/card";
import type { Mission, UserMission } from "@/lib/missions/data";
import { activityLabels } from "@/lib/mission-rounds";

type MissionActivityFormProps = {
  mission: Mission;
  participation: UserMission;
  pending: boolean;
};

export function MissionActivityForm({ mission, participation, pending }: MissionActivityFormProps) {
  return (
    <Card className="p-5 sm:p-6">
      <div className="flex items-start gap-3">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-sky-50 text-sky-800">
          <FileCheck2 size={19} aria-hidden="true" />
        </span>
        <div>
          <h2 className="text-lg font-semibold text-slate-950">ส่งผลกิจกรรม</h2>
          <p className="mt-1 text-sm leading-6 text-slate-600">
            {mission.requires_evidence
              ? "ภารกิจนี้ต้องแนบลิงก์หรือบันทึกหลักฐาน การส่งจะรอผู้ดูแลตรวจสอบก่อน"
              : "ส่งผลกิจกรรมเพื่อให้ผู้ดูแลตรวจสอบก่อนเพิ่มความคืบหน้าและแต้ม"}
          </p>
        </div>
      </div>

      {pending ? (
        <div className="mt-5 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-950">
          มีรายการส่งที่กำลังรอตรวจสอบอยู่ เมื่อผู้ดูแลตรวจแล้ว คุณจึงจะส่งผลครั้งต่อไปได้
        </div>
      ) : (
        <form action={submitMissionActivityAction} className="mt-5 space-y-4">
          <input type="hidden" name="missionId" value={mission.id} />
          <input type="hidden" name="userMissionId" value={participation.id} />
          {(mission.allowed_activity_types?.length ?? 0) > 1 ? <label className="block text-sm font-semibold text-slate-700">ประเภทกิจกรรม<select name="activityType" className="mt-2 min-h-12 w-full rounded-2xl border p-3" required defaultValue={mission.activity_type}>{mission.allowed_activity_types?.map(type => <option value={type} key={type}>{activityLabels[type] ?? type}</option>)}</select></label> : <input type="hidden" name="activityType" value={mission.activity_type}/>}
          <label className="block space-y-2 text-sm font-semibold text-slate-700">
            ผลกิจกรรม ({mission.target_unit})
            <input
              name="value"
              type="number"
              inputMode="decimal"
              min={["steps", "sessions", "count"].includes(mission.target_unit) ? "1" : "0.001"}
              max={Number(mission.target_value) - Number(participation.progress_value)}
              step={["steps", "sessions", "count"].includes(mission.target_unit) ? "1" : "0.001"}
              required
              className="min-h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 font-normal outline-none transition focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100"
            />
          </label>
          <label className="block space-y-2 text-sm font-semibold text-slate-700">
            ลิงก์หลักฐาน <span className="font-normal text-slate-500">(ถ้ามี)</span>
            <input
              name="evidenceUrl"
              type="url"
              maxLength={2048}
              placeholder="https://..."
              className="min-h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 font-normal outline-none transition placeholder:text-slate-400 focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100"
            />
          </label>
          <label className="block space-y-2 text-sm font-semibold text-slate-700">
            บันทึกเพิ่มเติม <span className="font-normal text-slate-500">(กรอกอย่างน้อยหนึ่งอย่างหากหลักฐานจำเป็น)</span>
            <textarea
              name="evidenceNotes"
              maxLength={2000}
              rows={3}
              placeholder="อธิบายผลกิจกรรมหรือหลักฐานของคุณ"
              className="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 font-normal outline-none transition placeholder:text-slate-400 focus:border-emerald-600 focus:ring-4 focus:ring-emerald-100"
            />
          </label>
          <PendingSubmitButton pendingLabel="กำลังส่งกิจกรรม...">ส่งให้ตรวจสอบ</PendingSubmitButton>
        </form>
      )}
    </Card>
  );
}
