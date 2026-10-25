type ProgressBarProps = {
  value: number;
  target: number;
  unit: string;
};

const numberFormat = new Intl.NumberFormat("th-TH", { maximumFractionDigits: 3 });

export function ProgressBar({ value, target, unit }: ProgressBarProps) {
  const percent = target > 0 ? Math.min(100, Math.max(0, (value / target) * 100)) : 0;

  return (
    <div aria-label={`ความคืบหน้า ${numberFormat.format(value)} จาก ${numberFormat.format(target)} ${unit}`}>
      <div className="mb-2 flex items-center justify-between gap-3 text-sm">
        <span className="font-semibold text-slate-800">ความคืบหน้า</span>
        <span className="text-slate-600">{numberFormat.format(value)} / {numberFormat.format(target)} {unit}</span>
      </div>
      <div
        className="h-3 overflow-hidden rounded-full bg-slate-100"
        role="progressbar"
        aria-valuenow={Math.round(percent)}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <div className="h-full rounded-full bg-emerald-600 transition-[width]" style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}
