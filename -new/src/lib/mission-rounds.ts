export const difficultyLabels = { easy: "ง่าย", medium: "ปานกลาง", hard: "ยาก" } as const;
export const activityLabels: Record<string, string> = { steps: "จำนวนก้าว", walk: "เดิน", run: "วิ่ง", cycle: "ปั่นจักรยาน", swim: "ว่ายน้ำ", check_in: "เช็กอิน", custom: "ออกกำลังกายรูปแบบอื่น" };
export function bangkokDay(at = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Bangkok", year: "numeric", month: "2-digit", day: "2-digit" }).formatToParts(at);
  return ["year", "month", "day"].map(type => parts.find(p => p.type === type)?.value).join("-");
}
export function isRoundDay(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const at = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(at.getTime()) && at.toISOString().slice(0, 10) === value;
}
export function roundStatus(round: { status: string; pending_value?: number; last_status?: string | null }): string {
  if (round.status === "completed") return "สำเร็จและอนุมัติแล้ว";
  if (Number(round.pending_value ?? 0) > 0) return "รอตรวจสอบ";
  if (round.last_status === "rejected") return "ไม่ผ่าน — ส่งใหม่ได้ภายในรอบวัน";
  return round.status === "expired" ? "หมดเวลา" : round.status === "cancelled" ? "ยกเลิก" : "กำลังทำ";
}
