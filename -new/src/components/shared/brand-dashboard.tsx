import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { requireRole } from "@/lib/auth/guards";
import { saveBrandItemAction, activateBrandItemAction, reviewBrandActivityAction, editBrandItemAction } from "@/app/actions/brand";
import { manageRedemptionAction } from "@/app/actions/rewards";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import { BrandItemForm, type CampaignItem, type ChallengeItem, type RewardOption } from "@/components/brand/item-form";

const errors: Record<string, string> = {
 review: "ตรวจไม่สำเร็จ กรุณาระบุเหตุผลอย่างน้อย 2 ตัวอักษรเมื่อปฏิเสธ หรือรายการนี้อาจถูกตรวจไปแล้ว",
 input: "ตรวจข้อมูลให้ครบ เป้าหมาย/แต้มต้องเป็นบวก หน่วยต้องตรงกับกิจกรรม และจำนวนที่นั่งต้องเป็นจำนวนเต็มหรือว่าง",
 dates: "ตรวจวันเริ่มและสิ้นสุด: ต้องเรียงตามเวลา อยู่ในช่วง Daily Mission และยังไม่หมดเวลาขณะเผยแพร่",
 locked: "มีผู้เข้าร่วมแล้วหรือรายการปิดแล้ว จึงแก้เงื่อนไขไม่ได้ ให้สร้างรายการใหม่แทน",
 unfinished: "ยังมีผู้เข้าร่วมทำไม่เสร็จหรือหลักฐานรอตรวจ กรุณาตรวจให้ครบก่อนปิดรายการ",
 parent: "เปิดใช้งาน Daily Mission ก่อน แล้วตรวจช่วงเวลาของ Challenge",
 permission: "บัญชีนี้ไม่มีสิทธิ์จัดการรายการดังกล่าว",
 migration: "ยังไม่ได้ติดตั้ง migration 202610250007_brand_campaign_management.sql",
 save: "บันทึกไม่สำเร็จ ตรวจสิทธิ์ Daily Mission รางวัล และเงื่อนไข แล้วลองใหม่",
};
const labels: Record<string, string> = {draft:"ฉบับร่าง",scheduled:"ตั้งเวลา",active:"เปิดรับ",paused:"หยุดรับคนใหม่",completed:"เสร็จสิ้น",cancelled:"ยกเลิก",archived:"เก็บถาวร"};
function dates(item: {starts_at: string | null; ends_at: string | null}) {
 const date = (v: string | null) => v ? new Intl.DateTimeFormat("th-TH",{dateStyle:"medium",timeStyle:"short",timeZone:"Asia/Bangkok"}).format(new Date(v)) : "ไม่กำหนด (รายการเดิม)";
 return `${date(item.starts_at)} – ${date(item.ends_at)} (เวลาไทย)`;
}
function StatusActions({kind,id,status}:{kind:"campaigns"|"challenges";id:string;status:string}) {
 if(["completed","cancelled","archived"].includes(status)) return null;
 return <div className="flex flex-wrap gap-3">
  <form action={activateBrandItemAction}><input type="hidden" name="kind" value={kind}/><input type="hidden" name="id" value={id}/><input type="hidden" name="status" value={status==="active"?"paused":"active"}/><PendingSubmitButton pendingLabel="กำลังเปลี่ยนสถานะ…">{status==="active"?"หยุดรับคนใหม่":"เผยแพร่ / เปิดรับ"}</PendingSubmitButton></form>
  {["active","paused"].includes(status)&&<details className="rounded-xl border p-3"><summary className="cursor-pointer text-sm">ปิดเป็นเสร็จสิ้น</summary><form action={activateBrandItemAction} className="mt-3 space-y-3"><input type="hidden" name="kind" value={kind}/><input type="hidden" name="id" value={id}/><input type="hidden" name="status" value="completed"/><label className="flex max-w-sm gap-2 text-sm"><input type="checkbox" name="confirmComplete" value="yes" required/>ยืนยันปิดรายการ โดยต้องไม่มีหลักฐานรอตรวจ และผู้เข้าร่วมทำครบหรือสิ้นสุดระยะเวลาแล้ว</label><PendingSubmitButton variant="secondary" pendingLabel="กำลังปิด…">ยืนยันเสร็จสิ้น</PendingSubmitButton></form></details>}
 </div>;
}

export async function BrandDashboard({searchParams}:{searchParams?:Promise<{error?:string;success?:string}>}) {
 const params=await searchParams;
 const user=await requireRole("brand","/brand");const db=await createClient();
 const members=await db.from("brand_memberships").select("brand_id,membership_role").eq("profile_id",user.id).eq("status","active");
 if(members.error) return <section className="p-6" role="alert">โหลดสิทธิ์ไม่สำเร็จ กรุณารีเฟรชเพื่อลองใหม่</section>;
 const brandIds=members.data?.map(m=>m.brand_id)??[];
 if(!brandIds.length) return <section className="p-6">ยังไม่มีสมาชิกแบรนด์ <Link href="/open-brand">เปิดบัญชีแบรนด์</Link></section>;
 const results=await Promise.all([
 db.from("campaigns").select("id,name,brand_id,status,objective,starts_at,ends_at").in("brand_id",brandIds).order("created_at",{ascending:false}),
 db.from("challenges").select("id,title,status,brand_id,campaign_id,description,mission_title,participation_terms,evidence_instructions,activity_type,target_value,target_unit,reward_points,requires_evidence,participant_limit,starts_at,ends_at,reward_id").in("brand_id",brandIds).order("created_at",{ascending:false}),
 db.from("rewards").select("id,brand_id,title,points_required").in("brand_id",brandIds),
 db.from("activities").select("id,value,unit,evidence_url,evidence_notes,challenge_participant_id").eq("verification_status","pending").not("challenge_participant_id","is",null),
 db.from("redemptions").select("id,redemption_code,status,reward_id"),
 db.from("campaign_results").select("campaign_id,campaign_name,participant_count,completion_count,points_awarded,activity_count")]);
 const [campaignResult,challengeResult,rewardResult,activities,redemptions,analytics]=results;
 const campaigns=(campaignResult.data??[]) as CampaignItem[], challenges=(challengeResult.data??[]) as ChallengeItem[], rewards=(rewardResult.data??[]) as RewardOption[];
 const challengeIds=challenges.map(c=>c.id);
 const participants=challengeIds.length?await db.from("challenge_participants").select("id,challenge_id,status,progress_value,completed_at").in("challenge_id",challengeIds).order("joined_at",{ascending:false}):{data:[],error:null};
 const managerIds=new Set(members.data?.filter(m=>["owner","manager"].includes(m.membership_role)).map(m=>m.brand_id));
 const ownedRewards=new Set(rewards.filter(r=>r.brand_id&&managerIds.has(r.brand_id)).map(r=>r.id));
 const campaignLocked=(id:string)=>Boolean(participants.error||challengeResult.error||participants.data?.some(p=>challenges.some(c=>c.id===p.challenge_id&&c.campaign_id===id)));
 const challengeLocked=(id:string)=>Boolean(participants.error||participants.data?.some(p=>p.challenge_id===id));
 return <section className="mx-auto max-w-5xl space-y-7 px-4 py-8 sm:p-6">
  <div><h1 className="text-3xl font-semibold">Daily Mission และ Challenge ของแบรนด์</h1><p className="mt-3 text-sm text-slate-600">สร้างฉบับร่าง → ตรวจข้อมูล → เปิด Daily Mission → เปิด Challenge แต่ละ Challenge มีภารกิจและเป้าหมายของตนเอง</p></div>
  {params?.error&&<p role="alert" className="rounded-xl bg-rose-50 p-4 text-rose-800">{errors[params.error]??errors.save}</p>}
  {params?.success&&<p role="status" className="rounded-xl bg-emerald-50 p-4 text-emerald-900">บันทึกสำเร็จ</p>}
  {(results.some(r=>r.error)||participants.error)&&<p role="alert" className="rounded-xl bg-amber-50 p-4">โหลดข้อมูลบางส่วนไม่สำเร็จ กรุณารีเฟรช หากเพิ่งอัปเดตให้ตรวจ migration ใหม่ก่อน ระบบจะไม่เปิดฟอร์มแก้เงื่อนไขเมื่อโหลดผู้เข้าร่วมไม่ได้</p>}
  <p className="rounded-xl border bg-white p-4 text-sm">เมื่อมีผู้เข้าร่วมจะล็อกเงื่อนไขสำคัญ หยุดเผยแพร่ได้โดยผู้เข้าร่วมเดิมยังส่งกิจกรรมภายในกำหนดได้ การปิดเสร็จสิ้นต้องไม่มีงานรอตรวจ</p>
  {!campaignResult.error&&!challengeResult.error&&!rewardResult.error&&[...managerIds].map(brandId=><div key={brandId} className="space-y-4">
   <details className="rounded-2xl border bg-white p-5"><summary className="cursor-pointer text-lg font-semibold">สร้าง Daily Mission</summary><div className="mt-5"><BrandItemForm kind="campaign" brandId={brandId} campaigns={campaigns} rewards={rewards} action={saveBrandItemAction}/></div></details>
   <details className="rounded-2xl border bg-white p-5"><summary className="cursor-pointer text-lg font-semibold">สร้าง Challenge และภารกิจ</summary><div className="mt-5">{campaigns.some(c=>c.brand_id===brandId&&["draft","scheduled","active","paused"].includes(c.status))?<BrandItemForm kind="challenge" brandId={brandId} campaigns={campaigns} rewards={rewards} action={saveBrandItemAction}/>:<p>สร้าง Daily Mission ฉบับร่างก่อน จึงเพิ่ม Challenge ได้</p>}</div></details>
  </div>)}
  <h2 className="text-2xl font-semibold">Daily Mission</h2>
  {!campaignResult.error&&!campaigns.length&&<p>ยังไม่มี Daily Mission เริ่มจากฟอร์มสร้างด้านบน</p>}
  {campaigns.map(c=><article key={c.id} className="min-w-0 space-y-4 break-words rounded-2xl border bg-white p-5"><h3 className="text-xl font-semibold">{c.name} <span className="text-sm text-emerald-800">{labels[c.status]??c.status}</span></h3><p className="whitespace-pre-wrap break-words">{c.objective}</p><p className="text-sm">{dates(c)}</p>
   {managerIds.has(c.brand_id)&&<><StatusActions kind="campaigns" id={c.id} status={c.status}/>{campaignLocked(c.id)||["completed","archived"].includes(c.status)?<p className="text-sm text-amber-800">เงื่อนไขถูกล็อก: มีผู้เข้าร่วมหรือรายการปิดแล้ว</p>:<details><summary className="cursor-pointer font-semibold text-emerald-800">แก้ไขก่อนมีผู้เข้าร่วม</summary><div className="mt-4"><BrandItemForm kind="campaign" brandId={c.brand_id} campaigns={campaigns} rewards={rewards} item={c} action={editBrandItemAction}/></div></details>}</>}
  </article>)}
  <h2 className="text-2xl font-semibold">Challenge และภารกิจ</h2>
  {!challengeResult.error&&!challenges.length&&<p>ยังไม่มี Challenge เลือก Daily Mission แล้วเพิ่มภารกิจด้านบน</p>}
  {challenges.map(c=>{const reward=rewards.find(r=>r.id===c.reward_id);return <article key={c.id} className="min-w-0 space-y-4 break-words rounded-2xl border bg-white p-5"><h3 className="text-xl font-semibold">{c.title} <span className="text-sm text-emerald-800">{labels[c.status]??c.status}</span></h3><p className="text-sm text-slate-600">Daily Mission: {campaigns.find(p=>p.id===c.campaign_id)?.name??"โหลดไม่ได้"}</p><p className="whitespace-pre-wrap break-words">{c.description}</p><p>ภารกิจ: {c.mission_title} · {c.target_value} {c.target_unit} ({c.activity_type})</p><p className="whitespace-pre-wrap">เงื่อนไข: {c.participation_terms}</p><p className="whitespace-pre-wrap">{c.requires_evidence?"ต้องส่งหลักฐาน":"รายละเอียดเพื่อประกอบการตรวจ"}: {c.evidence_instructions}</p><p>{dates(c)}</p><p>ผู้เข้าร่วม {participants.error?"โหลดไม่ได้":participants.data?.filter(p=>p.challenge_id===c.id).length??0} / {c.participant_limit??"ไม่จำกัด"}</p><p>สำเร็จและตรวจผ่าน: ได้ {c.reward_points} แต้ม</p><p className="text-sm">{reward?`รางวัลแนะนำ: ${reward.title} ใช้ ${reward.points_required} แต้มแลกแยก` : "นำแต้มไปเลือกรางวัลภายหลัง"} · ไม่แจกคูปองอัตโนมัติ</p>
   {managerIds.has(c.brand_id)&&<><StatusActions kind="challenges" id={c.id} status={c.status}/>{challengeLocked(c.id)||["completed","cancelled"].includes(c.status)?<p className="text-sm text-amber-800">ล็อกเงื่อนไขหลังมีผู้เข้าร่วมหรือปิดรายการแล้ว</p>:<details><summary className="cursor-pointer font-semibold text-emerald-800">แก้ไขก่อนมีผู้เข้าร่วม</summary><div className="mt-4"><BrandItemForm kind="challenge" brandId={c.brand_id} campaigns={campaigns} rewards={rewards} item={c} action={editBrandItemAction}/></div></details>}</>}
  </article>})}
  <h2 className="text-xl font-semibold">ผู้เข้าร่วม</h2>
  {!participants.error&&!participants.data?.length&&<p>ยังไม่มีผู้เข้าร่วม</p>}
  {participants.data?.map(p=><article key={p.id} className="rounded-xl border bg-white p-4"><p>{challenges.find(c=>c.id===p.challenge_id)?.title}</p><p>ผู้เข้าร่วม #{p.id.slice(0,8)} · {p.status} · ความคืบหน้า {p.progress_value}</p></article>)}
  <h2 className="text-xl font-semibold">ตรวจหลักฐาน</h2>
  {!activities.error&&!activities.data?.length&&<p>ไม่มีหลักฐานรอตรวจ</p>}
  {activities.data?.map(a=><article key={a.id} className="rounded-xl border bg-white p-4"><p>{a.value} {a.unit} · {a.evidence_notes}</p>{a.evidence_url&&/^https?:\/\//i.test(a.evidence_url)&&<a href={a.evidence_url} target="_blank" rel="noreferrer" className="mt-2 inline-block break-all font-semibold text-emerald-800 underline">เปิดหลักฐาน</a>}<form action={reviewBrandActivityAction} className="mt-3 flex flex-wrap gap-3"><input type="hidden" name="id" value={a.id}/><label className="w-full text-sm">หมายเหตุ / เหตุผลเมื่อไม่ผ่าน (อย่างน้อย 2 ตัวอักษร)<textarea name="reviewerNote" maxLength={1000} rows={2} className="mt-2 w-full rounded-xl border p-3"/></label><PendingSubmitButton name="approved" value="true" pendingLabel="กำลังตรวจ…">อนุมัติ</PendingSubmitButton><PendingSubmitButton name="approved" value="false" variant="secondary" pendingLabel="กำลังตรวจ…">ปฏิเสธ</PendingSubmitButton></form></article>)}
  <h2 className="text-xl font-semibold">ส่งมอบรางวัล</h2>
  {redemptions.data?.filter(r=>ownedRewards.has(r.reward_id)).map(r=><article key={r.id} className="rounded-xl border bg-white p-4"><p>{r.redemption_code} · {r.status}</p>{r.status==="requested"&&<form action={manageRedemptionAction} className="mt-3 flex flex-wrap gap-3"><input type="hidden" name="redemptionId" value={r.id}/><PendingSubmitButton name="operation" value="fulfill_redemption" pendingLabel="กำลังบันทึก…">ยืนยันส่งมอบ</PendingSubmitButton><PendingSubmitButton name="operation" value="refund_redemption" variant="secondary" pendingLabel="กำลังคืนแต้ม…">ยกเลิกและคืนแต้ม</PendingSubmitButton></form>}</article>)}
  <h2 className="text-xl font-semibold">ผลลัพธ์เบื้องต้น</h2>
  <p className="text-xs text-slate-600">นับการเข้าร่วมต่อ Challenge คนเดียวร่วมหลาย Challenge นับหลายรายการ · อัตราสำเร็จ = รายการสำเร็จ / รายการเข้าร่วม</p>
  {analytics.data?.map(a=><p key={a.campaign_id}>{a.campaign_name}: เข้าร่วม {a.participant_count} · สำเร็จ {a.completion_count} · {Number(a.participant_count)?Math.round(Number(a.completion_count)/Number(a.participant_count)*100):0}% · กิจกรรม {a.activity_count} · แต้มที่แจก {a.points_awarded}</p>)}
 </section>;
}
