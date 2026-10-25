import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getSupabasePublicConfig } from "@/lib/env";
import { getAuthenticatedUser } from "@/lib/auth/session";
import { challengeAction } from "@/app/actions/challenges";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
const date=(v:string|null)=>v?new Date(v).toLocaleString("th-TH",{timeZone:"Asia/Bangkok"}):"ไม่กำหนด";
export default async function ChallengesPage({searchParams}:{searchParams:Promise<{error?:string;success?:string}>}) {
 const params=await searchParams;
 if(!getSupabasePublicConfig()) return <section className="p-8">กรุณาตั้งค่า Supabase เพื่อดู Challenges</section>;
 const db=await createClient();const user=await getAuthenticatedUser();
 const {data:joined,error:joinError}=user?await db.from("challenge_participants").select("id,challenge_id,status,progress_value").eq("user_id",user.id):{data:[],error:null};
 const ids=joined?.map(j=>j.challenge_id)??[];
 const query=db.from("challenges").select("id,title,brand_id,description,mission_title,participation_terms,evidence_instructions,requires_evidence,status,starts_at,ends_at,target_value,target_unit,reward_points,participant_limit,reward_id");
 const {data,error}=await (ids.length?query.or(`status.eq.active,id.in.(${ids.join(",")})`):query.eq("status","active"));
 const brandIds=[...new Set(data?.map(c=>c.brand_id)??[])],rewardIds=[...new Set(data?.flatMap(c=>c.reward_id?[c.reward_id]:[])??[])];
 const brands=brandIds.length?await db.from("brands").select("id,name").in("id",brandIds):{data:[],error:null};
 const rewards=rewardIds.length?await db.from("rewards").select("id,title,points_required").in("id",rewardIds):{data:[],error:null};
 return <section className="mx-auto max-w-5xl space-y-6 p-4 sm:p-6"><h1 className="text-3xl font-semibold">Challenges</h1>
 {params.error&&<p role="alert" className="rounded-xl bg-rose-50 p-4">{params.error==="full"?"Challenge เต็มแล้ว กรุณาเลือกรายการอื่น":"ทำรายการไม่สำเร็จ ตรวจช่วงเวลา ข้อมูลหลักฐาน และรายการที่รอตรวจ แล้วลองใหม่"}</p>}
 {params.success&&<p role="status" className="rounded-xl bg-emerald-50 p-4">บันทึกสำเร็จ</p>}
 {(error||joinError||brands.error||rewards.error)&&<p role="alert">โหลดข้อมูลบางส่วนไม่สำเร็จ กรุณารีเฟรช หากเพิ่งอัปเดตให้ตรวจ migration ใหม่</p>}
 {data?.map(c=>{const participation=joined?.find(j=>j.challenge_id===c.id),reward=rewards.data?.find(r=>r.id===c.reward_id);return <article key={c.id} className="min-w-0 space-y-3 break-words rounded-2xl border bg-white p-5">
  <p className="text-sm text-emerald-800">{brands.data?.find(b=>b.id===c.brand_id)?.name??"โหลดชื่อแบรนด์ไม่ได้"}</p><h2 className="text-xl font-semibold">{c.title}</h2><p className="whitespace-pre-wrap">{c.description}</p><p>ภารกิจ: {c.mission_title}</p><p>เป้าหมาย {c.target_value} {c.target_unit} · สำเร็จและตรวจผ่านได้ {c.reward_points} แต้ม</p>
  <p className="whitespace-pre-wrap">เงื่อนไข: {c.participation_terms}</p><p>{date(c.starts_at)} – {date(c.ends_at)} (เวลาไทย)</p><p>จำนวนผู้เข้าร่วมสูงสุด: {c.participant_limit??"ไม่จำกัด"}</p>
  <p className="whitespace-pre-wrap">{c.requires_evidence?"หลักฐานที่ต้องส่ง":"รายละเอียดประกอบการตรวจ"}: {c.evidence_instructions}</p>
  <p className="text-sm">{reward?<Link href={`/rewards/${reward.id}`} className="text-emerald-800 underline">รางวัลแนะนำ: {reward.title} ใช้ {reward.points_required} แต้มแลกแยก</Link>:<Link href="/rewards" className="text-emerald-800 underline">นำแต้มไปเลือกรางวัล</Link>} · ไม่ได้รับคูปองอัตโนมัติ ขึ้นกับราคา สต็อก และเงื่อนไขขณะแลก</p>
  {!participation?<form action={challengeAction}><input type="hidden" name="operation" value="join"/><input type="hidden" name="id" value={c.id}/><label className="mb-3 flex gap-2 text-sm"><input type="checkbox" required/>ฉันอ่านเงื่อนไขและช่วงเวลาแล้ว</label><PendingSubmitButton pendingLabel="กำลังเข้าร่วม…">เข้าร่วม</PendingSubmitButton></form>:<><p>สถานะ {participation.status} · ความคืบหน้าที่อนุมัติ {participation.progress_value}/{c.target_value}</p>
  {c.status==="paused"&&<p className="text-sm text-amber-800">หยุดรับคนใหม่ ผู้เข้าร่วมเดิมยังส่งกิจกรรมได้ภายในระยะเวลาเดิม</p>}
  {["joined","in_progress"].includes(participation.status)&&["active","paused"].includes(c.status)&&<form action={challengeAction} className="grid gap-3 sm:grid-cols-2"><input type="hidden" name="operation" value="submit"/><input type="hidden" name="id" value={participation.id}/><label className="text-sm">จำนวนกิจกรรม<input className="mt-1 min-h-11 w-full rounded-xl border p-3" name="value" type="number" min="0.001" step="0.001" max={Number(c.target_value)-Number(participation.progress_value)} required/></label><label className="text-sm">URL หลักฐาน<input className="mt-1 min-h-11 w-full rounded-xl border p-3" name="evidenceUrl" type="url" maxLength={2048}/></label><label className="text-sm sm:col-span-2">รายละเอียดหลักฐาน<textarea className="mt-1 w-full rounded-xl border p-3" name="notes" maxLength={2000} rows={3}/></label><div><PendingSubmitButton pendingLabel="กำลังส่ง…">ส่งให้แบรนด์ตรวจ</PendingSubmitButton></div></form>}
  </>}
 </article>})}
 {!error&&!data?.length&&<p>ยังไม่มี Challenge ที่เปิดอยู่หรือรายการที่คุณเข้าร่วม</p>}
 </section>;
}
