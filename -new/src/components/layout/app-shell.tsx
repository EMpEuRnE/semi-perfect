import Link from "next/link";
import {
  Activity,
  Building2,
  ChartNoAxesColumn,
  Gift,
  History,
  LayoutDashboard,
  LogIn,
  ShieldCheck,
  Target,
  UserRound,
  Wallet,
  type LucideIcon,
} from "lucide-react";
import { signOutAction } from "@/app/actions/auth";
import { getAuthenticatedUser, getProfileRole } from "@/lib/auth/session";
import { hasActiveBrandMembership } from "@/lib/auth/brand-access";
import { BrandMark } from "@/components/layout/brand-mark";
import { Container } from "@/components/ui/container";
import { buttonLinkClass } from "@/components/ui/button";
import { PendingSubmitButton } from "@/components/ui/pending-submit-button";
import type { AppRole } from "@/lib/auth/roles";

const navigation: Record<AppRole, Array<{ href: string; label: string; icon: LucideIcon }>> = {
  user: [
    { href: "/progress", label: "Progress", icon: ChartNoAxesColumn },
    { href: "/missions", label: "ภารกิจ", icon: Target },
    { href: "/challenges", label: "ชาเลนจ์", icon: Activity },
    { href: "/rewards", label: "รางวัล", icon: Gift },
    { href: "/wallet", label: "กระเป๋าแต้ม", icon: Wallet },
    { href: "/history", label: "ประวัติ", icon: History },
  ],
  brand: [
    { href: "/brand", label: "ภาพรวม", icon: LayoutDashboard },
    { href: "/brand/campaigns", label: "Daily Mission", icon: Building2 },
    { href: "/brand/challenges", label: "ชาเลนจ์", icon: Target },
    { href: "/brand/analytics", label: "ผลลัพธ์", icon: ChartNoAxesColumn },
  ],
  admin: [
    { href: "/admin", label: "ผู้ดูแลระบบ", icon: ShieldCheck },
  ],
};

export async function AppShell({ role, children }: { role: AppRole; children: React.ReactNode }) {
  const user = await getAuthenticatedUser();
  const actualRole = user ? await getProfileRole(user.id) : null;
  const brandAccess = actualRole === "brand" && user ? await hasActiveBrandMembership(user.id) : false;
  const items = navigation[role];

  return (
    <div className="min-h-screen bg-[#f7f9f6] pb-20 md:pb-0">
      <header className="sticky top-0 z-30 border-b border-slate-200/80 bg-white/90 backdrop-blur-xl">
        <Container className="flex min-h-[76px] items-center gap-5">
          <BrandMark href={role === "brand" ? "/brand" : role === "admin" ? "/admin" : "/"} />
          <nav aria-label={role === "brand" ? "เมนูแบรนด์" : role === "admin" ? "เมนูผู้ดูแลระบบ" : "เมนูหลัก"} className="hidden min-w-0 flex-1 md:block">
            <ul className="flex items-center gap-1 overflow-x-auto">
              {items.map((item) => (
                <li key={item.href}>
                  <Link href={item.href} className="inline-flex min-h-10 items-center gap-2 whitespace-nowrap rounded-full px-3 text-sm font-medium text-slate-600 transition-colors hover:bg-emerald-50 hover:text-emerald-800">
                    <item.icon size={16} aria-hidden="true" />
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
          <div className="ml-auto flex shrink-0 items-center gap-2">
            {role === "user" ? (
              <Link href={brandAccess ? "/brand" : "/open-brand"} className="inline-flex items-center gap-2 rounded-full px-2 py-2 text-xs font-medium text-slate-600 hover:bg-slate-100 sm:px-3 sm:text-sm">
                <Building2 size={16} aria-hidden="true" /> {brandAccess ? "จัดการแบรนด์" : "เปิดแบรนด์"}
              </Link>
            ) : (
              <Link href="/" className="hidden rounded-full px-3 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100 sm:inline-flex">
                ไปหน้าผู้ใช้
              </Link>
            )}
            {user ? (
              <>
                <Link href="/profile" className="inline-flex size-10 items-center justify-center rounded-full bg-emerald-50 text-emerald-800" aria-label={`โปรไฟล์${actualRole === "admin" ? "ผู้ดูแลระบบ" : brandAccess ? "แบรนด์" : "ผู้ใช้"}`}>
                  <UserRound size={18} aria-hidden="true" />
                </Link>
                <form action={signOutAction}>
                  <PendingSubmitButton variant="ghost" className="hidden min-h-10 px-3 py-2 text-sm font-medium sm:inline-flex" pendingLabel="กำลังออกจากระบบ...">
                    ออกจากระบบ
                  </PendingSubmitButton>
                </form>
              </>
            ) : (
              <Link href="/login" className={buttonLinkClass("secondary")}>
                <LogIn size={16} aria-hidden="true" /> เข้าสู่ระบบ
              </Link>
            )}
          </div>
        </Container>
      </header>

      <main>{children}</main>

      <nav aria-label="เมนูบนมือถือ" className="fixed inset-x-0 bottom-0 z-40 overflow-x-auto border-t border-slate-200 bg-white/95 px-2 pb-[max(env(safe-area-inset-bottom),0.5rem)] pt-2 backdrop-blur-xl md:hidden">
        <ul className="mx-auto flex min-w-max max-w-lg items-center justify-around gap-1">
          {items.map((item) => (
            <li key={item.href}>
              <Link href={item.href} className="flex min-w-16 flex-col items-center gap-1 rounded-xl px-2 py-1.5 text-[11px] font-medium text-slate-600 hover:text-emerald-800">
                <item.icon size={19} aria-hidden="true" />
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </div>
  );
}
