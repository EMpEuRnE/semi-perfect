import Link from "next/link";
import {requireAuthenticatedUser} from "@/lib/auth/guards";
import {ProgressOverview} from "@/components/progress/overview";
import {Container} from "@/components/ui/container";
export const dynamic="force-dynamic";
export default async function ProgressPage({searchParams}:{searchParams:Promise<{state?:string}>}) {
 const user=await requireAuthenticatedUser("/progress"),params=await searchParams;
 const filter=["active","pending","completed","closed"].includes(params.state??"")?params.state:"all";
 return <Container className="space-y-6 py-8"><h1 className="text-3xl font-semibold">ติดตาม Progress</h1><p className="text-sm text-slate-600">ยอดที่ส่งให้ตรวจยังไม่ใช่ความคืบหน้าที่ผ่านการอนุมัติ แต้มได้เมื่อครบเป้าหมายและตรวจผ่านเท่านั้น</p><nav aria-label="กรองความคืบหน้า" className="flex flex-wrap gap-2">{[["all","ทั้งหมด"],["active","กำลังทำ"],["pending","รอตรวจ"],["completed","สำเร็จ"],["closed","ปิดแล้ว"]].map(([value,label])=><Link key={value} href={`/progress?state=${value}`} aria-current={filter===value?"page":undefined} className={`rounded-full border px-4 py-3 text-sm ${filter===value?"bg-emerald-700 text-white":"bg-white"}`}>{label}</Link>)}</nav><ProgressOverview userId={user.id} filter={filter}/></Container>;
}
