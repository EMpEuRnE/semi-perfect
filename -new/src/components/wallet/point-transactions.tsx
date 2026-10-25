import { ArrowDownLeft, ArrowUpRight, Sparkles } from "lucide-react";
import type { PointTransaction } from "@/lib/missions/data";

const numbers = new Intl.NumberFormat("th-TH");
const dates = new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" });

export function PointTransactions({ transactions, emptyText = "ยังไม่มีรายการแต้ม" }: {
  transactions: PointTransaction[];
  emptyText?: string;
}) {
  if (transactions.length === 0) {
    return <p className="py-6 text-center text-sm text-slate-600">{emptyText}</p>;
  }

  return (
    <ul className="divide-y divide-slate-100">
      {transactions.map((transaction) => {
        const isEarn = Number(transaction.amount) > 0;
        const Icon = isEarn ? ArrowDownLeft : ArrowUpRight;
        return (
          <li key={transaction.id} className="flex items-center gap-3 py-4 first:pt-0 last:pb-0">
            <span className={`flex size-10 shrink-0 items-center justify-center rounded-full ${isEarn ? "bg-emerald-50 text-emerald-800" : "bg-amber-50 text-amber-900"}`}>
              {transaction.source === "mission" ? <Sparkles size={18} aria-hidden="true" /> : <Icon size={18} aria-hidden="true" />}
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-slate-900">{transaction.description}</p>
              <p className="mt-1 text-xs text-slate-500">{dates.format(new Date(transaction.created_at))}</p>
            </div>
            <p className={`shrink-0 text-sm font-bold ${isEarn ? "text-emerald-800" : "text-slate-800"}`}>
              {isEarn ? "+" : "−"}{numbers.format(Math.abs(Number(transaction.amount)))} แต้ม
            </p>
          </li>
        );
      })}
    </ul>
  );
}
