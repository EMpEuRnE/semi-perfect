import Link from "next/link";
import { Activity } from "lucide-react";

export function BrandMark({ href = "/" }: { href?: string }) {
  return (
    <Link href={href} className="inline-flex shrink-0 items-center gap-2.5" aria-label="Move & Earn หน้าหลัก">
      <span className="flex size-10 items-center justify-center rounded-2xl bg-emerald-700 text-white shadow-sm">
        <Activity size={21} strokeWidth={2.5} aria-hidden="true" />
      </span>
      <span className="text-lg font-bold tracking-tight text-slate-950">Move <span className="text-emerald-700">&</span> Earn</span>
    </Link>
  );
}
