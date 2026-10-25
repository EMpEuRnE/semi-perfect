import Link from "next/link";
import {getProgressData} from "@/lib/progress";
import {ProgressBar} from "@/components/core/progress-bar";
const labels={active:"กำลังทำ",pending:"รอตรวจสอบ",completed:"สำเร็จและอนุมัติแล้ว",closed:"สิ้นสุดรอบ / ปิดแล้ว"};
export async function ProgressOverview({userId,compact=false,filter="all"}:{userId:string;compact?:boolean;filter?:string}) {
 const state=await getProgressData(userId);
 if(state.status!=="ready")return <p role="alert" className="rounded-xl bg-rose-50 p-4">โหลดความคืบหน้าไม่สำเร็จ กรุณารีเฟรชและตรวจการเชื่อมต่อฐานข้อมูล</p>;
 const selected=state.data.filter(item=>compact?["active","pending"].includes(item.state):filter==="all"||item.state===filter);
 const items=compact?selected.slice(0,4):selected;
 return <div className="space-y-4"><div className="flex flex-wrap items-center justify-between gap-3"><h2 className="text-xl font-semibold">{compact?"ภารกิจและ Challenge ที่กำลังทำ":"ความคืบหน้าของฉัน"}</h2>{compact&&<Link href="/progress" className="font-semibold text-emerald-800 underline">ดูทั้งหมด</Link>}</div>
 {!items.length&&<p className="rounded-xl border bg-white p-5">ยังไม่มีรายการในกลุ่มนี้ <Link href="/missions" className="text-emerald-800 underline">เลือกภารกิจ</Link> หรือ <Link href="/challenges" className="text-emerald-800 underline">เข้าร่วม Challenge</Link></p>}
 <div className="grid gap-4 md:grid-cols-2">{items.map(item=><article key={item.id} className="min-w-0 space-y-3 break-words rounded-2xl border bg-white p-5"><p className="text-xs text-slate-500">{item.type==="mission"?"Mission":"Challenge"}{item.day?` · รอบ ${item.day} เวลาไทย`:""}</p><h3 className="text-lg font-semibold">{item.title}</h3><p className="text-sm font-semibold text-emerald-800">{labels[item.state]}</p><p className="text-xs text-slate-600">ความคืบหน้าที่อนุมัติแล้ว</p><ProgressBar value={item.approved} target={item.target} unit={item.unit}/><p className="text-sm">รอตรวจ {item.pending} {item.unit} — ยังไม่นับเป็นความคืบหน้าหรือแต้ม</p><p className="text-sm">{item.points} แต้มเมื่อครบและอนุมัติ</p>{item.note&&<p className="rounded-xl bg-rose-50 p-3 text-sm text-rose-800">ไม่ผ่าน: {item.note}</p>}<Link href={item.href} className="inline-flex min-h-11 items-center font-semibold text-emerald-800 underline">{item.state==="active"?"ทำต่อ / ส่งหลักฐาน":"ดูรายละเอียดและผลตรวจ"}</Link></article>)}</div>
 {!compact&&<p className="text-xs text-slate-500">แสดงสูงสุด 50 รอบ Mission และ 50 การเข้าร่วม Challenge ล่าสุด</p>}</div>;
}
