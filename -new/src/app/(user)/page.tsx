import Link from "next/link";
import { ProgressOverview } from "@/components/progress/overview";
import { Activity, ArrowRight, ArrowUpRight, Check, ClipboardCheck, History, MoveRight, ShieldCheck, Sparkles, Target, Wallet, Zap } from "lucide-react";
import { Card } from "@/components/ui/card";
import { Container } from "@/components/ui/container";
import { buttonLinkClass } from "@/components/ui/button";
import { getAuthenticatedUser } from "@/lib/auth/session";
import { getWalletData } from "@/lib/missions/data";

export const dynamic = "force-dynamic";

const steps = [
  { icon: Target, number: "01", title: "Mission", text: "เลือกภารกิจและเริ่มทำ" },
  { icon: Activity, number: "02", title: "Activity", text: "ส่งผลกิจกรรมพร้อมหลักฐาน" },
  { icon: ClipboardCheck, number: "03", title: "Verification", text: "ผู้ดูแลตรวจผลก่อนให้แต้ม" },
  { icon: Zap, number: "04", title: "Points", text: "แต้มถูกเพิ่มในบัญชีธุรกรรม" },
  { icon: Wallet, number: "05", title: "Wallet", text: "ตรวจยอดและประวัติแต้ม" },
];

export default async function HomePage() {
  const user = await getAuthenticatedUser();
  const wallet = user ? await getWalletData(user.id) : null;

  return (
    <>
      {user && <Container className="py-8"><ProgressOverview userId={user.id} compact/></Container>}
      <section className="relative isolate overflow-hidden">
        <div className="pointer-events-none absolute -right-28 -top-36 -z-10 size-[32rem] rounded-full bg-emerald-100/70 blur-3xl" />
        <Container className="grid min-h-[620px] items-center gap-12 py-16 lg:grid-cols-[1.05fr_0.95fr] lg:py-20">
          <div className="max-w-2xl">
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-emerald-100 bg-white/80 px-4 py-2 text-sm font-semibold text-emerald-800 shadow-sm">
              <Sparkles size={16} aria-hidden="true" /> ทุกก้าวเล็ก ๆ มีความหมาย
            </div>
            <h1 className="text-5xl font-semibold leading-[1.05] tracking-tight text-slate-950 sm:text-6xl lg:text-7xl">
              ขยับวันนี้<br />รับสิ่งดี ๆ <span className="text-emerald-700">กลับไป</span>
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-8 text-slate-600 sm:text-xl">
              ทำภารกิจ ส่งผลให้ตรวจสอบ แล้วรับแต้มเข้ากระเป๋า ทุกขั้นตอนมีประวัติจากฐานข้อมูล
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link href="/missions" className={buttonLinkClass()}>
                ค้นหาภารกิจ <ArrowRight size={17} aria-hidden="true" />
              </Link>
              <Link href={user ? "/wallet" : "/register"} className={buttonLinkClass("secondary")}>
                {user ? "ดูกระเป๋าแต้ม" : "สมัครเพื่อเริ่ม"} <ArrowUpRight size={16} aria-hidden="true" />
              </Link>
            </div>
            <div className="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm text-slate-500">
              <span className="inline-flex items-center gap-2"><Check size={16} className="text-emerald-700" aria-hidden="true" /> ตรวจสอบก่อนให้แต้ม</span>
              <span className="inline-flex items-center gap-2"><Check size={16} className="text-emerald-700" aria-hidden="true" /> ยอดแต้มมาจากฐานข้อมูล</span>
              <span className="inline-flex items-center gap-2"><Check size={16} className="text-emerald-700" aria-hidden="true" /> ดูประวัติย้อนหลังได้</span>
            </div>
            {wallet?.status === "ready" ? (
              <Link href="/wallet" className="mt-7 inline-flex items-center gap-3 rounded-2xl border border-emerald-100 bg-white px-4 py-3 shadow-sm transition hover:border-emerald-300">
                <Wallet size={19} className="text-emerald-800" aria-hidden="true" />
                <span><span className="block text-xs text-slate-500">แต้มคงเหลือของคุณ</span><span className="font-semibold text-slate-950">{new Intl.NumberFormat("th-TH").format(wallet.data.balance)} แต้ม</span></span>
                <ArrowRight size={16} className="ml-2 text-emerald-800" aria-hidden="true" />
              </Link>
            ) : null}
          </div>

          <div className="relative mx-auto w-full max-w-lg">
            <div className="absolute -inset-4 rounded-[2.5rem] bg-gradient-to-br from-emerald-200/60 via-lime-100/60 to-transparent blur-xl" />
            <Card className="relative overflow-hidden border-white/80 bg-white/95 p-6 shadow-xl shadow-emerald-950/5 sm:p-8">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <p className="text-sm font-medium text-slate-500">เริ่มต้นเส้นทางของคุณ</p>
                  <h2 className="mt-1 text-2xl font-semibold text-slate-950">Mission → Wallet</h2>
                </div>
                <span className="flex size-12 items-center justify-center rounded-2xl bg-lime-100 text-emerald-800"><Activity size={23} aria-hidden="true" /></span>
              </div>
              <div className="mt-8 space-y-3">
                {steps.map((step, index) => (
                  <div key={step.number} className="flex items-center gap-4 rounded-2xl border border-slate-100 bg-slate-50/80 p-3.5">
                    <span className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-white text-emerald-800 shadow-sm"><step.icon size={20} aria-hidden="true" /></span>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2">
                        <p className="font-semibold text-slate-900">{step.title}</p>
                        <span className="text-[10px] font-bold tracking-widest text-slate-400">{step.number}</span>
                      </div>
                      <p className="mt-1 text-sm leading-5 text-slate-500">{step.text}</p>
                    </div>
                    {index < steps.length - 1 ? <MoveRight size={17} className="hidden shrink-0 text-slate-300 sm:block" aria-hidden="true" /> : null}
                  </div>
                ))}
              </div>
              <Link href="/register" className="mt-5 inline-flex w-full items-center justify-center gap-2 rounded-2xl bg-emerald-700 px-5 py-4 text-sm font-semibold text-white transition hover:bg-emerald-800">
                เริ่มต้นใช้งาน <ArrowRight size={17} aria-hidden="true" />
              </Link>
            </Card>
          </div>
        </Container>
      </section>

      <section className="border-y border-slate-200/80 bg-white py-16 sm:py-20">
        <Container>
          <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
            <div className="max-w-xl">
              <p className="text-xs font-bold uppercase tracking-[0.18em] text-emerald-700">เริ่มง่าย ทำต่อได้</p>
              <h2 className="mt-3 text-3xl font-semibold tracking-tight text-slate-950 sm:text-4xl">ก้าวเล็ก ๆ สู่ความเปลี่ยนแปลงที่ดี</h2>
            </div>
            <Link href="/missions" className="inline-flex items-center gap-2 text-sm font-semibold text-emerald-800 hover:underline">
              ดูเส้นทางภารกิจ <MoveRight size={16} aria-hidden="true" />
            </Link>
          </div>
          <div className="mt-9 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
            {steps.map((step) => (
              <Card key={step.number} className="p-6 sm:p-7">
                <div className="flex size-12 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-800"><step.icon size={22} aria-hidden="true" /></div>
                <p className="mt-6 text-xs font-bold tracking-[0.16em] text-slate-400">STEP {step.number}</p>
                <h3 className="mt-2 text-xl font-semibold text-slate-950">{step.title}</h3>
                <p className="mt-2 text-sm leading-6 text-slate-600">{step.text}</p>
              </Card>
            ))}
          </div>
        </Container>
      </section>

      <section className="py-16 sm:py-20">
        <Container>
          <Card className="flex flex-col items-start justify-between gap-6 overflow-hidden bg-emerald-950 p-7 text-white sm:flex-row sm:items-center sm:p-10">
            <div className="max-w-2xl">
              <p className="text-xs font-bold uppercase tracking-[0.18em] text-emerald-300">เชื่อถือได้ทุกขั้นตอน</p>
              <h2 className="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl">กิจกรรมผ่านการตรวจ ก่อนเพิ่มแต้ม</h2>
              <p className="mt-3 text-sm leading-6 text-emerald-100/80 sm:text-base">ผลกิจกรรมจะอยู่ในสถานะรอตรวจสอบ แต้มจะถูกเพิ่มลงใน ledger เมื่อผู้ดูแลอนุมัติและภารกิจครบเป้าหมาย</p>
            </div>
            <Link href={user ? "/history" : "/missions"} className="inline-flex min-h-12 shrink-0 items-center gap-2 rounded-full bg-lime-300 px-5 py-3 text-sm font-semibold text-emerald-950 transition hover:bg-lime-200">
              {user ? "ดูประวัติของฉัน" : "เริ่มจากภารกิจ"} {user ? <History size={17} aria-hidden="true" /> : <ShieldCheck size={17} aria-hidden="true" />}
            </Link>
          </Card>
        </Container>
      </section>
    </>
  );
}
