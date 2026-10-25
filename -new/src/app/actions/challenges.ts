"use server";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { requireAuthenticatedUser } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
import { field, uuid } from "@/lib/brand-validation";
export async function challengeAction(form: FormData) {
 await requireAuthenticatedUser("/challenges");
 const operation=field(form,"operation"), id=field(form,"id"), notes=field(form,"notes"), evidenceUrl=field(form,"evidenceUrl"), value=Number(field(form,"value"));
 if(!["join","submit"].includes(operation)||!uuid.test(id)) redirect("/challenges?error=input");
 if(operation==="submit") {
  if(!Number.isFinite(value)||value<=0||notes.length>2000||evidenceUrl.length>2048) redirect("/challenges?error=input");
  if(evidenceUrl) {
   let valid:boolean;try { valid=["http:","https:"].includes(new URL(evidenceUrl).protocol); } catch { valid=false; }
   if(!valid) redirect("/challenges?error=input");
  }
 }
 let failure: string|null=null;
 try {
  const db=await createClient();
  const {error}=operation==="join"?await db.rpc("join_challenge",{p_challenge_id:id}):await db.rpc("submit_challenge_activity",{p_participant_id:id,p_value:value,p_evidence_notes:notes||null,p_evidence_url:evidenceUrl||null});
  if(error) failure=error.message.includes("participant limit")?"full":"operation";
 } catch { failure="operation"; }
 revalidatePath("/challenges");revalidatePath("/brand");revalidatePath("/progress");revalidatePath("/");
 redirect(failure?`/challenges?error=${failure}`:"/challenges?success=1");
}
