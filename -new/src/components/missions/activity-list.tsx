import { CheckCircle2, Clock3, XCircle } from "lucide-react";
import { Card } from "@/components/ui/card";
import type { MissionActivity } from "@/lib/missions/data";

const numbers = new Intl.NumberFormat("th-TH", { maximumFractionDigits: 3 });
const dates = new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Bangkok" });

const activityStatus = {
  pending: { label: "รอตรวจสอบ", icon: Clock3, className: "bg-amber-50 text-amber-900" },
  approved: { label: "ผ่านการตรวจสอบ", icon: CheckCircle2, className: "bg-emerald-50 text-emerald-900" },
  rejected: { label: "ไม่ผ่านการตรวจสอบ", icon: XCircle, className: "bg-rose-50 text-rose-900" },
} as const;

function safeEvidenceUrl(value: string | null) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:" ? url.href : null;
  } catch {
    return null;
  }
}

export function ActivityList({ activities }: { activities: MissionActivity[] }) {
  if (activities.length === 0) {
    return <p className="mt-4 text-sm text-slate-600">ยังไม่มีการส่งกิจกรรม</p>;
  }

  return (
    <ul className="mt-4 space-y-3">
      {activities.map((activity) => {
        const status = activityStatus[activity.verification_status];
        const Icon = status.icon;
        const evidenceHref = safeEvidenceUrl(activity.evidence_url);
        return (
          <li key={activity.id}>
            <Card className="p-4">
              <div className="flex flex-wrap items-center justify-between gap-3">
                <p className="font-semibold text-slate-900">{numbers.format(Number(activity.value))} {activity.unit}</p>
                <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold ${status.className}`}>
                  <Icon size={14} aria-hidden="true" /> {status.label}
                </span>
              </div>
              <p className="mt-2 text-xs text-slate-500">ส่งเมื่อ {dates.format(new Date(activity.created_at))}</p>
              {activity.evidence_notes ? <p className="mt-3 whitespace-pre-wrap text-sm leading-6 text-slate-700">{activity.evidence_notes}</p> : null}
              {evidenceHref ? (
                <a className="mt-2 inline-block break-all text-sm font-medium text-emerald-800 underline" href={evidenceHref} target="_blank" rel="noreferrer">
                  เปิดหลักฐาน
                </a>
              ) : null}
              {activity.reviewer_note ? <p className="mt-3 rounded-xl bg-slate-50 px-3 py-2 text-sm text-slate-700">หมายเหตุ: {activity.reviewer_note}</p> : null}
            </Card>
          </li>
        );
      })}
    </ul>
  );
}
