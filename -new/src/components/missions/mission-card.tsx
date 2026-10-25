import Link from "next/link";
import { ArrowRight, Sparkles } from "lucide-react";
import { joinMissionAction } from "@/app/actions/missions";
import { Card } from "@/components/ui/card";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { ProgressBar } from "@/components/core/progress-bar";
import { bangkokDay, difficultyLabels, roundStatus } from "@/lib/mission-rounds";
import type { Mission, UserMission } from "@/lib/missions/data";
const numbers = new Intl.NumberFormat("th-TH", { maximumFractionDigits: 3 });
export function MissionCard({ mission, participation, authenticated = false }: { mission: Mission; participation: UserMission | null; authenticated?: boolean }) {
 const linkClass="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-full bg-emerald-700 px-5 py-2.5 text-sm font-semibold text-white hover:bg-emerald-800";
 return <Card className="flex h-full min-w-0 flex-col space-y-4 break-words p-5 sm:p-6">
  <div className="flex flex-wrap items-center justify-between gap-2"><Sparkles size={20} className="text-emerald-800" aria-hidden="true"/><span className="rounded-full bg-lime-50 px-3 py-1 text-xs font-semibold text-emerald-900">{difficultyLabels[mission.difficulty]}</span></div>
  <div><p className="text-xs text-slate-500">{mission.recurrence === "daily" ? `ภารกิจรายวัน · รอบ ${bangkokDay()} (เวลาไทย)` : "ภารกิจทั่วไป"}</p><h2 className="mt-2 text-xl font-semibold text-slate-950">{mission.title}</h2></div>
  <p className="line-clamp-3 text-sm leading-6 text-slate-600">{mission.description}</p>
  <p className="line-clamp-3 text-sm text-slate-600">เงื่อนไข: {mission.participation_terms}</p>
  <p className="font-semibold text-emerald-800">{numbers.format(mission.points)} แต้ม เมื่อครบเป้าหมายและตรวจผ่าน</p>
  <p className="text-sm">เป้าหมาย {numbers.format(Number(mission.target_value))} {mission.target_unit} · {mission.requires_evidence ? "ต้องส่งหลักฐาน" : "ส่งผลให้ตรวจสอบ"}</p>
  {participation ? <div className="space-y-3"><p className="text-sm font-semibold">{roundStatus(participation)}</p><p className="text-xs text-slate-600">ความคืบหน้าที่อนุมัติแล้ว</p><ProgressBar value={Number(participation.progress_value)} target={Number(mission.target_value)} unit={mission.target_unit}/><p className="text-xs text-slate-600">ส่งทั้งหมด {numbers.format(Number(participation.reported_value ?? 0))} {mission.target_unit} (รวมรายการไม่ผ่านและส่งซ้ำ)<br/>รอตรวจ {numbers.format(Number(participation.pending_value ?? 0))} {mission.target_unit} — ยังไม่นับเป็นความคืบหน้า</p></div> : <p className="text-sm text-slate-500">ยังไม่เริ่ม · อนุมัติแล้ว 0 / {numbers.format(Number(mission.target_value))}</p>}
  <div className="mt-auto pt-2">{!participation && authenticated ? <form action={joinMissionAction}><input type="hidden" name="missionId" value={mission.id}/><PendingSubmitButton className="w-full" pendingLabel="กำลังเริ่ม…">{mission.recurrence === "daily" ? "เริ่มภารกิจวันนี้" : "เริ่มภารกิจ"}</PendingSubmitButton></form> : <Link href={`/missions/${mission.id}`} className={linkClass}>{participation?.status === "completed" ? "ดูผลที่อนุมัติแล้ว" : participation ? "ทำต่อ / ดูผลตรวจ" : "ดูรายละเอียดและเริ่ม"}<ArrowRight size={16} aria-hidden="true"/></Link>}</div>
  {!participation && authenticated && <Link href={`/missions/${mission.id}`} className="text-center text-sm font-semibold text-emerald-800 underline">อ่านรายละเอียดและเงื่อนไข</Link>}
 </Card>;
}
