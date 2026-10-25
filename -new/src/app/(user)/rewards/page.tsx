import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getSupabasePublicConfig } from "@/lib/env";
import { getAuthenticatedUser } from "@/lib/auth/session";
export default async function RewardsPage({searchParams}: {searchParams:Promise<{error?:string;success?:string}>}) {
 const params = await searchParams;
 if (!getSupabasePublicConfig()) return <section className="p-8">กรุณาตั้งค่า Supabase เพื่อดูรางวัล</section>;
 const db=await createClient(); const user=await getAuthenticatedUser();
 const {data:rewards,error}=await db.from("rewards").select("id,title,description,category,points_required,stock,expires_at").eq("status","active");
 const balanceResult=user?await db.from("user_point_balances").select("balance").eq("user_id",user.id).maybeSingle():{data:null,error:null};
 const balance=balanceResult.error?null:Number(balanceResult.data?.balance??0);
 const {data:claims,error:claimError}=user ? await db.from("redemptions").select("id,redemption_code,status,points_spent").eq("user_id",user.id).order("created_at",{ascending:false}) : {data:[],error:null};
 return <section className="mx-auto max-w-5xl space-y-6 p-6"><h1 className="text-3xl font-bold">รางวัล</h1><p>แต้มใช้แลกรางวัลภายในแพลตฟอร์ม ไม่ใช่เงินสด และไม่มีอัตรา 1 แต้ม = 1 บาท รางวัลทั้งหมดในเดโมเป็นตัวอย่าง</p>
 {user&&<p className="font-semibold text-emerald-800">แต้มคงเหลือ: {balance===null?"โหลดไม่ได้":balance}</p>}
 {params.error && <p role="alert">แลกรางวัลไม่สำเร็จ โปรดตรวจแต้ม สต็อก และยืนยันในหน้ารายละเอียด</p>}{params.success && <p role="status">แลกรางวัลสำเร็จ รหัสสาธิตแสดงด้านล่าง ใช้กับร้านค้าจริงไม่ได้</p>}
 {(error || claimError || balanceResult.error) && <p role="alert">โหลดข้อมูลไม่สำเร็จ กรุณาลองใหม่</p>}
 <div className="grid gap-4 md:grid-cols-2">{rewards?.map(r=><article className="rounded-2xl border bg-white p-5" key={r.id}><h2 className="text-xl font-bold"><Link href={`/rewards/${r.id}`}>{r.title}</Link></h2><p className="text-sm text-emerald-700">{r.category}</p><p>{r.description}</p><p>{r.points_required} แต้ม · คงเหลือ {r.stock ?? "ไม่จำกัด"}</p><Link href={`/rewards/${r.id}`} className="mt-3 inline-flex min-h-11 items-center rounded-full bg-emerald-700 px-5 py-2 text-sm font-semibold text-white">{r.stock===0?"หมดแล้ว — ดูรายละเอียด":balance!==null&&balance<r.points_required&&user?"แต้มยังไม่พอ — ดูรายละเอียด":"ดูรายละเอียดและยืนยันแลก"}</Link></article>)}</div>
 {!error && !rewards?.length && <p>ยังไม่มีรางวัลพร้อมแลก</p>}
 <h2 className="text-xl font-bold">รางวัลของฉัน</h2>{!claimError&&!claims?.length&&<p>ยังไม่มีประวัติการแลกรางวัล</p>}{claims?.map(r=><article key={r.id} className="rounded-xl border p-4"><p>รหัส: <strong>{r.redemption_code}</strong></p><p>{r.status==="requested"?"แลกแล้ว / รอส่งมอบ (เดโม)":r.status==="fulfilled"?"ส่งมอบแล้ว":r.status==="refunded"?"คืนแต้มแล้ว":r.status} · {r.points_spent} แต้ม</p></article>)}
 </section>;
}
