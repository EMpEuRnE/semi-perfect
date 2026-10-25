"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAuthenticatedUser, requireRole } from "@/lib/auth/guards";
import { getSupabasePublicConfig } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function readString(formData: FormData, name: string) {
  const value = formData.get(name);
  return typeof value === "string" ? value.trim() : "";
}

function isEvidenceUrl(value: string) {
  if (!value) return true;
  try {
    const url = new URL(value);
    return (url.protocol === "http:" || url.protocol === "https:") && value.length <= 2048;
  } catch {
    return false;
  }
}

export async function joinMissionAction(formData: FormData) {
  const missionId = readString(formData, "missionId");
  if (!uuidPattern.test(missionId)) redirect("/missions?error=mission");

  await requireAuthenticatedUser(`/missions/${missionId}`);
  if (!getSupabasePublicConfig()) redirect(`/missions/${missionId}?error=setup`);

  let failed: boolean;
  try {
    const supabase = await createClient();
    const { error } = await supabase.rpc("join_mission", { p_mission_id: missionId });
    failed = Boolean(error);
  } catch {
    failed = true;
  }
  if (failed) redirect(`/missions/${missionId}?error=join`);

  revalidatePath("/missions");
  revalidatePath(`/missions/${missionId}`);
  redirect(`/missions/${missionId}?joined=1`);
}

export async function submitMissionActivityAction(formData: FormData) {
  const userMissionId = readString(formData, "userMissionId");
  const missionId = readString(formData, "missionId");
  const rawValue = readString(formData, "value");
  const evidenceUrl = readString(formData, "evidenceUrl");
  const evidenceNotes = readString(formData, "evidenceNotes");
  const activityType = readString(formData, "activityType");
  const value = Number(rawValue);

  if (!uuidPattern.test(userMissionId) || !uuidPattern.test(missionId)) {
    redirect("/missions?error=mission");
  }
  await requireAuthenticatedUser(`/missions/${missionId}`);

  if (!Number.isFinite(value) || value <= 0 || evidenceNotes.length > 2000 || !isEvidenceUrl(evidenceUrl)) {
    redirect(`/missions/${missionId}?error=invalid-activity`);
  }
  if (!getSupabasePublicConfig()) redirect(`/missions/${missionId}?error=setup`);

  let failure: "pending" | "evidence-required" | "activity" | null = null;
  try {
    const supabase = await createClient();
    const { error } = await supabase.rpc("submit_mission_activity", {
      p_user_mission_id: userMissionId,
      p_value: value,
      p_evidence_url: evidenceUrl || null,
      p_evidence_notes: evidenceNotes || null,
      p_activity_type: activityType || null,
    });

    if (error) {
      if (error.message.includes("Daily mission round has ended")) {
        failure = "activity";
      } else if (error.code === "23505" || error.message.includes("pending submission")) {
        failure = "pending";
      } else if (error.message.includes("Evidence is required")) {
        failure = "evidence-required";
      } else {
        failure = "activity";
      }
    }
  } catch {
    failure = "activity";
  }
  if (failure) redirect(`/missions/${missionId}?error=${failure}`);

  revalidatePath("/missions");
  revalidatePath(`/missions/${missionId}`);
  revalidatePath("/wallet");
  revalidatePath("/history");
  revalidatePath("/progress");
  revalidatePath("/");
  redirect(`/missions/${missionId}?submitted=1`);
}

export async function reviewMissionActivityAction(formData: FormData) {
  const activityId = readString(formData, "activityId");
  const missionId = readString(formData, "missionId");
  const approvedValue = readString(formData, "approved");
  const reviewerNote = readString(formData, "reviewerNote");

  await requireRole("admin", "/admin");
  if (!uuidPattern.test(activityId) || !uuidPattern.test(missionId)
    || !["true", "false"].includes(approvedValue) || reviewerNote.length > 1000 || (approvedValue === "false" && reviewerNote.length < 2)) {
    redirect("/admin?error=review-input");
  }
  if (!getSupabasePublicConfig()) redirect("/admin?error=setup");

  let failed: boolean;
  try {
    const supabase = await createClient();
    const { error } = await supabase.rpc("review_activity", {
      p_activity_id: activityId,
      p_approved: approvedValue === "true",
      p_reviewer_note: reviewerNote || null,
    });
    failed = Boolean(error);
  } catch {
    failed = true;
  }
  if (failed) redirect("/admin?error=review");

  revalidatePath("/admin");
  revalidatePath("/missions");
  revalidatePath(`/missions/${missionId}`);
  revalidatePath("/wallet");
  revalidatePath("/history");
  revalidatePath("/progress");
  revalidatePath("/");
  redirect(`/admin?reviewed=${approvedValue === "true" ? "approved" : "rejected"}`);
}
