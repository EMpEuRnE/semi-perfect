import type { LucideIcon } from "lucide-react";
import { ArrowUpRight } from "lucide-react";
import Link from "next/link";
import { Card } from "@/components/ui/card";
import { Container } from "@/components/ui/container";
import { PageHeading } from "@/components/ui/page-heading";
import type { AppRole } from "@/lib/auth/roles";

type RoutePlaceholderProps = {
  eyebrow: string;
  title: string;
  description: string;
  icon: LucideIcon;
  audience?: AppRole;
};

export function RoutePlaceholder({ eyebrow, title, description, icon: Icon, audience = "user" }: RoutePlaceholderProps) {
  const homeHref = audience === "brand" ? "/brand" : audience === "admin" ? "/admin" : "/";

  return (
    <Container className="py-12 sm:py-16">
      <PageHeading eyebrow={eyebrow} title={title} description={description} />
      <Card className="mt-10 flex flex-col items-start gap-6 p-6 sm:flex-row sm:items-center sm:p-8">
        <div className="flex size-14 shrink-0 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-800">
          <Icon size={26} aria-hidden="true" />
        </div>
        <div className="max-w-xl">
          <h2 className="text-lg font-semibold text-slate-900">พื้นที่นี้พร้อมต่อยอดแล้ว</h2>
          <p className="mt-2 text-sm leading-6 text-slate-600">
            โครงหน้าและ navigation ถูกเตรียมไว้แล้ว เนื้อหาการทำงานจริงจะเพิ่มในเฟสถัดไป
          </p>
        </div>
        <Link href={homeHref} className="inline-flex shrink-0 items-center gap-2 rounded-full px-4 py-2 text-sm font-semibold text-emerald-800 hover:bg-emerald-50 sm:ml-auto">
          กลับหน้าหลัก <ArrowUpRight size={16} aria-hidden="true" />
        </Link>
      </Card>
    </Container>
  );
}
