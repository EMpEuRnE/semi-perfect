"use server";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { requireAuthenticatedUser, requireRole } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";
export async function redeemRewardAction(form: FormData) {
  await requireAuthenticatedUser("/rewards");
  if (form.get("confirmRedeem") !== "yes") redirect("/rewards?error=confirm");
  const id = String(form.get("rewardId") ?? "");
  if (!/^[0-9a-f-]{36}$/i.test(id)) redirect("/rewards?error=invalid");
  const requestId = String(form.get("requestId") ?? "");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(requestId)) redirect("/rewards?error=invalid");
  let failed: boolean;
  try { const db = await createClient(); const {error} = await db.rpc("redeem_reward", {p_reward_id:id,p_request_id:requestId}); failed = !!error; } catch { failed = true; }
  if (failed) redirect("/rewards?error=redeem");
  revalidatePath("/wallet"); revalidatePath("/rewards"); revalidatePath("/progress"); revalidatePath("/");
  redirect("/rewards?success=1");
}
export async function manageRedemptionAction(form: FormData) {
  await requireRole("brand", "/brand");
  const operation = String(form.get("operation"));
  if (!["fulfill_redemption", "refund_redemption"].includes(operation)) redirect("/brand?error=invalid");
  const db = await createClient();
  const {error} = await db.rpc(operation, {p_redemption_id:String(form.get("redemptionId"))});
  revalidatePath("/brand"); revalidatePath("/rewards"); revalidatePath("/wallet");
  redirect(error ? "/brand?error=operation" : "/brand?success=1");
}
