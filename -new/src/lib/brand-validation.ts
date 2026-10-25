export const activityUnits: Record<string, readonly string[]> = {
  steps: ["steps"], walk: ["km", "miles", "minutes"], run: ["km", "miles", "minutes"],
  cycle: ["km", "miles", "minutes"], swim: ["km", "miles", "minutes"],
  check_in: ["count", "sessions"], custom: ["count", "sessions", "minutes", "km", "miles", "steps"],
};
export const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function field(form: FormData, name: string) { return String(form.get(name) ?? "").trim(); }
function text(form: FormData, name: string, max: number) {
  const value = field(form, name);
  if (value.length < 2 || value.length > max) throw new Error("input");
  return value;
}
export function bangkokDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) throw new Error("dates");
  const millis = Date.parse(`${value}+07:00`);
  if (!Number.isFinite(millis) || new Date(millis + 7 * 3600000).toISOString().slice(0, 16) !== value) throw new Error("dates");
  return new Date(millis).toISOString();
}
export function localDate(value: string | null) {
  return value ? new Date(new Date(value).getTime() + 7 * 3600000).toISOString().slice(0, 16) : "";
}
export function parseBrandFields(form: FormData, kind: "campaign" | "challenge") {
  const title = text(form, "title", 160), description = text(form, "description", 2000);
  const starts_at = bangkokDate(field(form, "startsAt")), ends_at = bangkokDate(field(form, "endsAt"));
  if (starts_at >= ends_at) throw new Error("dates");
  if (kind === "campaign") return { name: title, objective: description, starts_at, ends_at };
  const activity_type = field(form, "activityType"), target_unit = field(form, "targetUnit");
  const target_value = Number(field(form, "target")), reward_points = Number(field(form, "points"));
  const limit = field(form, "participantLimit"), participant_limit = limit ? Number(limit) : null;
  if (!activityUnits[activity_type]?.includes(target_unit) || !Number.isFinite(target_value) || target_value <= 0 || target_value > 99999999999.999
    || Math.abs(target_value * 1000 - Math.round(target_value * 1000)) > 0.001
    || (["steps", "count", "sessions"].includes(target_unit) && !Number.isInteger(target_value))
    || !Number.isInteger(reward_points) || reward_points <= 0 || reward_points > 2147483647
    || (participant_limit !== null && (!Number.isInteger(participant_limit) || participant_limit < 1 || participant_limit > 2147483647))) throw new Error("input");
  const reward_id = field(form, "rewardId") || null;
  if (reward_id && !uuid.test(reward_id)) throw new Error("input");
  return { title, description, objective: description, starts_at, ends_at,
    mission_title: text(form, "missionTitle", 160), participation_terms: text(form, "terms", 2000),
    evidence_instructions: text(form, "evidenceInstructions", 2000), requires_evidence: form.get("requiresEvidence") === "yes",
    activity_type, target_unit, target_value, reward_points, participant_limit, reward_id };
}
