"use server";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { requireRole } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import { field, parseBrandFields, uuid } from "@/lib/brand-validation";

function refreshBrand() {
 for (const path of ["/brand", "/brand/campaigns", "/brand/challenges", "/brand/create-challenge", "/brand/analytics", "/challenges"]) revalidatePath(path);
}
function errorCode(error: { code?: string; message?: string } | null) {
 if (!error) return null;
 const message = error.message ?? "";
 if (message.includes("locked") || message.includes("final")) return "locked";
 if (message.includes("pending reviews") || message.includes("participant activity")) return "unfinished";
 if (message.includes("dates") || message.includes("expired")) return "dates";
 if (message.includes("parent campaign")) return "parent";
 if (error.code === "42501" || error.code === "PGRST116") return "permission";
 if (error.code === "42703" || error.code === "PGRST204") return "migration";
 return "save";
}
async function persist(form: FormData, edit: boolean) {
 await requireRole("brand", "/brand");
 const kind = field(form, "kind");
 if (kind !== "campaign" && kind !== "challenge") redirect("/brand?error=input");
 let values: ReturnType<typeof parseBrandFields>;
 try { values = parseBrandFields(form, kind); }
 catch (error) { redirect(`/brand?error=${error instanceof Error && error.message === "dates" ? "dates" : "input"}`); }
 const id = field(form, "id"), brandId = field(form, "brandId"), campaignId = field(form, "campaignId");
 if (edit ? !uuid.test(id) : !uuid.test(brandId) || (kind === "challenge" && !uuid.test(campaignId))) redirect("/brand?error=input");
 let failure: string | null;
 try {
  const db = await createClient();
  const table = kind === "campaign" ? "campaigns" : "challenges";
  // RLS verifies the actor against the persisted brand; edits cannot move ownership.
  const query = edit ? db.from(table).update(values).eq("id", id)
    : db.from(table).insert({ ...values, brand_id: brandId, ...(kind === "challenge" ? { campaign_id: campaignId } : {}) });
  const { error } = await query.select("id").single();
  failure = errorCode(error);
 } catch { failure = "save"; }
 refreshBrand();
 redirect(failure ? `/brand?error=${failure}` : "/brand?success=1");
}
export async function saveBrandItemAction(form: FormData) { await persist(form, false); }
export async function editBrandItemAction(form: FormData) { await persist(form, true); }
export async function activateBrandItemAction(form: FormData) {
 await requireRole("brand", "/brand");
 const kind = field(form, "kind"), status = field(form, "status"), id = field(form, "id");
 if (!["campaigns", "challenges"].includes(kind) || !["active", "paused", "completed"].includes(status) || !uuid.test(id)) redirect("/brand?error=input");
 if (status === "completed" && form.get("confirmComplete") !== "yes") redirect("/brand?error=input");
 let failure: string | null;
 try {
  const db = await createClient();
  const { error } = await db.from(kind).update({ status }).eq("id", id).select("id").single();
  failure = errorCode(error);
 } catch { failure = "save"; }
 refreshBrand();
 redirect(failure ? `/brand?error=${failure}` : "/brand?success=1");
}

export async function reviewBrandActivityAction(form:FormData) {
 await requireRole("brand", "/brand");const db=await createClient();
 const note=field(form,"reviewerNote");
 const approved=String(form.get("approved"));if(!["true","false"].includes(approved)||note.length>1000||(approved==="false"&&note.length<2)) redirect("/brand?error=review");
 const {error}=await db.rpc("review_activity",{p_activity_id:String(form.get("id")),p_approved:approved==="true",p_reviewer_note:note||null});
 revalidatePath("/brand");revalidatePath("/wallet");revalidatePath("/challenges");revalidatePath("/progress");revalidatePath("/");
 redirect(error?"/brand?error=review":"/brand?success=1");
}
