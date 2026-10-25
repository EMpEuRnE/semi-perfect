import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { localDate } from "@/lib/brand-validation";

export type CampaignItem = { id: string; brand_id: string; name: string; objective: string; status: string; starts_at: string | null; ends_at: string | null };
export type ChallengeItem = { id: string; brand_id: string; campaign_id: string; title: string; description: string; status: string;
  mission_title: string; participation_terms: string; evidence_instructions: string; requires_evidence: boolean;
  activity_type: string; target_value: number; target_unit: string; reward_points: number; participant_limit: number | null;
  starts_at: string | null; ends_at: string | null; reward_id: string | null };
export type RewardOption = { id: string; brand_id: string | null; title: string; points_required: number };

export function BrandItemForm({ kind, brandId, campaigns, rewards, item, action }: {
  kind: "campaign" | "challenge"; brandId: string; campaigns: CampaignItem[]; rewards: RewardOption[];
  item?: CampaignItem | ChallengeItem; action: (form: FormData) => Promise<void>;
}) {
  const challenge = item && "mission_title" in item ? item : undefined;
  const campaign = item && "name" in item ? item : undefined;
  const inputClass = "mt-1 min-h-11 min-w-0 w-full rounded-xl border border-slate-300 bg-white px-3 py-2 font-normal text-slate-900";
  const labelClass = "block min-w-0 text-sm font-semibold text-slate-700";
  return <form action={action} className="grid gap-4 sm:grid-cols-2">
    <input type="hidden" name="kind" value={kind}/><input type="hidden" name="brandId" value={brandId}/>
    {item && <input type="hidden" name="id" value={item.id}/>}
    <label className={`${labelClass} sm:col-span-2`}>{kind === "campaign" ? "ชื่อ Daily Mission" : "ชื่อ Challenge"}<input name="title" required minLength={2} maxLength={160} defaultValue={campaign?.name ?? challenge?.title} className={inputClass}/></label>
    <label className={`${labelClass} sm:col-span-2`}>รายละเอียด<textarea name="description" required minLength={2} maxLength={2000} rows={3} defaultValue={campaign?.objective ?? challenge?.description} className={inputClass}/></label>
    {kind === "challenge" && <>
      {!item && <label className={`${labelClass} sm:col-span-2`}>Daily Mission<select name="campaignId" required className={inputClass} defaultValue=""><option value="" disabled>เลือก Daily Mission ของแบรนด์นี้</option>{campaigns.filter(c => c.brand_id === brandId && ["draft", "scheduled", "active", "paused"].includes(c.status)).map(c => <option key={c.id} value={c.id}>{c.name} ({c.status})</option>)}</select></label>}
      <label className={`${labelClass} sm:col-span-2`}>ภารกิจภายใน Challenge<input name="missionTitle" required minLength={2} maxLength={160} defaultValue={challenge?.mission_title} className={inputClass}/></label>
      <label className={labelClass}>ประเภทกิจกรรม<select name="activityType" defaultValue={challenge?.activity_type ?? "walk"} className={inputClass}>{[["steps","จำนวนก้าว"],["walk","เดิน"],["run","วิ่ง"],["cycle","ปั่นจักรยาน"],["swim","ว่ายน้ำ"],["check_in","เช็กอิน"],["custom","กิจกรรมอื่น"]].map(([v,l]) => <option key={v} value={v}>{l}</option>)}</select></label>
      <label className={labelClass}>หน่วย<select name="targetUnit" defaultValue={challenge?.target_unit ?? "km"} className={inputClass}>{[["km","กิโลเมตร"],["miles","ไมล์"],["minutes","นาที"],["steps","ก้าว"],["sessions","ครั้งกิจกรรม"],["count","ครั้ง"]].map(([v,l]) => <option key={v} value={v}>{l}</option>)}</select></label>
      <p className="text-xs text-slate-600 sm:col-span-2">จำนวนก้าวใช้หน่วยก้าว · เดิน/วิ่ง/ปั่น/ว่ายใช้กิโลเมตร ไมล์ หรือนาที · เช็กอินใช้ครั้ง</p>
      <label className={labelClass}>เป้าหมาย<input name="target" type="number" min="0.001" max="99999999999.999" step="0.001" required defaultValue={challenge?.target_value} className={inputClass}/></label>
      <label className={labelClass}>แต้มที่ได้เมื่อสำเร็จและผ่านการตรวจ<input name="points" type="number" min="1" max="2147483647" step="1" required defaultValue={challenge?.reward_points} className={inputClass}/></label>
      <label className={`${labelClass} sm:col-span-2`}>เงื่อนไขการเข้าร่วม<textarea name="terms" required minLength={2} maxLength={2000} rows={3} defaultValue={challenge?.participation_terms} className={inputClass}/></label>
      <label className="flex items-center gap-3 text-sm sm:col-span-2"><input type="checkbox" name="requiresEvidence" value="yes" defaultChecked={challenge?.requires_evidence ?? true}/>ต้องส่งหลักฐานประกอบการตรวจ</label>
      <label className={`${labelClass} sm:col-span-2`}>หลักฐาน / รายละเอียดที่ต้องส่ง<textarea name="evidenceInstructions" required minLength={2} maxLength={2000} rows={2} defaultValue={challenge?.evidence_instructions} className={inputClass}/></label>
      <label className={labelClass}>จำนวนผู้เข้าร่วมสูงสุด (ว่าง = ไม่จำกัด)<input name="participantLimit" type="number" min="1" max="2147483647" step="1" defaultValue={challenge?.participant_limit ?? ""} className={inputClass}/></label>
      <label className={labelClass}>รางวัลแนะนำสำหรับใช้แต้มแลก<select name="rewardId" defaultValue={challenge?.reward_id ?? ""} className={inputClass}><option value="">เลือกรางวัลจากหน้ารางวัลภายหลัง</option>{rewards.filter(r => r.brand_id === brandId).map(r => <option key={r.id} value={r.id}>{r.title} · ใช้ {r.points_required} แต้ม</option>)}</select></label>
      <p className="text-xs text-slate-600 sm:col-span-2">สำเร็จแล้วได้แต้ม ไม่ได้รับคูปองอัตโนมัติ ต้องกดแลกแยกตามราคา สต็อก และเงื่อนไขปัจจุบัน หากยังไม่มีรางวัลให้เลือก ผู้ใช้ยังสะสมแต้มได้</p>
    </>}
    <label className={labelClass}>เริ่ม (เวลาไทย UTC+7)<input name="startsAt" type="datetime-local" required defaultValue={localDate(item?.starts_at ?? null)} className={inputClass}/></label>
    <label className={labelClass}>สิ้นสุด (เวลาไทย UTC+7)<input name="endsAt" type="datetime-local" required defaultValue={localDate(item?.ends_at ?? null)} className={inputClass}/></label>
    <div className="sm:col-span-2"><PendingSubmitButton pendingLabel="กำลังบันทึก…">{item ? "บันทึกการแก้ไข" : `สร้าง ${kind === "campaign" ? "Daily Mission" : "Challenge"} ฉบับร่าง`}</PendingSubmitButton></div>
  </form>;
}
