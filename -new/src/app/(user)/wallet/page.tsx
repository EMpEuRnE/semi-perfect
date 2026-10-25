import Link from "next/link";
import { ArrowDownLeft, ArrowUpRight, History, Wallet } from "lucide-react";
import { requireAuthenticatedUser } from "@/lib/auth/guards";
import { getWalletData } from "@/lib/missions/data";
import { Notice, EmptyState } from "@/components/core/notice";
import { PointTransactions } from "@/components/wallet/point-transactions";
import { Card } from "@/components/ui/card";
import { Container } from "@/components/ui/container";
import { PageHeading } from "@/components/ui/page-heading";

export const dynamic = "force-dynamic";

export default async function WalletPage() {
  const user = await requireAuthenticatedUser("/wallet");
  const state = await getWalletData(user.id);

  return (
    <Container className="py-10 sm:py-14">
      <PageHeading eyebrow="USER · WALLET" title="กระเป๋าแต้ม" description="ยอดแต้มคำนวณจากบัญชีธุรกรรมในฐานข้อมูล และอัปเดตหลังรายการได้รับการตรวจสอบ" />

      {state.status === "setup" ? (
        <div className="mt-8"><Notice tone="error" title="ยังเชื่อมต่อ Supabase ไม่ได้">ตรวจสอบการตั้งค่าสภาพแวดล้อมสำหรับพัฒนา</Notice></div>
      ) : state.status === "error" ? (
        <div className="mt-8"><Notice tone="error" title="โหลดกระเป๋าแต้มไม่สำเร็จ">โปรดลองโหลดหน้านี้อีกครั้ง</Notice></div>
      ) : (
        <>
          <section aria-label="สรุปแต้ม" className="mt-8 grid gap-4 sm:grid-cols-3">
            <Card className="bg-emerald-950 p-5 text-white sm:col-span-3 sm:p-7">
              <div className="flex flex-wrap items-end justify-between gap-4">
                <div>
                  <p className="text-sm font-medium text-emerald-100">แต้มคงเหลือ</p>
                  <p className="mt-2 text-4xl font-bold tracking-tight sm:text-5xl">{new Intl.NumberFormat("th-TH").format(state.data.balance)}</p>
                </div>
                <Wallet size={34} className="text-lime-300" aria-hidden="true" />
              </div>
              <p className="mt-4 text-sm text-emerald-100/80">ยอดนี้มาจากผลรวม point_transactions ที่อ่านได้ของบัญชีคุณ</p>
            </Card>
            <Card className="p-5">
              <div className="flex items-center gap-2 text-sm font-medium text-slate-600"><ArrowDownLeft size={17} className="text-emerald-700" aria-hidden="true" /> ได้รับทั้งหมด</div>
              <p className="mt-3 text-2xl font-bold text-emerald-800">{new Intl.NumberFormat("th-TH").format(state.data.earned)} แต้ม</p>
            </Card>
            <Card className="p-5">
              <div className="flex items-center gap-2 text-sm font-medium text-slate-600"><ArrowUpRight size={17} className="text-amber-700" aria-hidden="true" /> ใช้ไปทั้งหมด</div>
              <p className="mt-3 text-2xl font-bold text-slate-900">{new Intl.NumberFormat("th-TH").format(state.data.spent)} แต้ม</p>
            </Card>
            <Card className="flex flex-col justify-between p-5">
              <div>
                <p className="text-sm font-medium text-slate-600">ทำภารกิจเพื่อรับแต้มเพิ่ม</p>
                <p className="mt-2 text-sm leading-6 text-slate-500">ผลกิจกรรมที่ผ่านการตรวจจะถูกบันทึกในกระเป๋าอัตโนมัติ</p>
              </div>
              <Link href="/missions" className="mt-4 inline-flex items-center gap-2 text-sm font-semibold text-emerald-800 hover:underline">ดูภารกิจ <History size={15} aria-hidden="true" /></Link>
            </Card>
          </section>

          <section className="mt-8">
            <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
              <div>
                <h2 className="text-xl font-semibold text-slate-950">รายการล่าสุด</h2>
                <p className="mt-1 text-sm text-slate-600">แสดงธุรกรรมล่าสุดจากบัญชีแต้ม</p>
              </div>
              <Link href="/history" className="text-sm font-semibold text-emerald-800 hover:underline">ดูประวัติทั้งหมด</Link>
            </div>
            <Card className="p-5 sm:p-6">
              {state.data.transactions.length === 0 ? (
                <EmptyState title="ยังไม่มีรายการแต้ม">เมื่อทำภารกิจสำเร็จ รายการที่ได้รับจะปรากฏที่นี่</EmptyState>
              ) : (
                <PointTransactions transactions={state.data.transactions} />
              )}
            </Card>
          </section>
        </>
      )}
    </Container>
  );
}
