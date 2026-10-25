"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { requireAuthenticatedUser } from "@/lib/auth/guards";
import { createClient } from "@/lib/supabase/server";

export async function openBrandAction(form: FormData) {
  await requireAuthenticatedUser("/open-brand");
  const name = String(form.get("brandName") ?? "").trim();
  const description = String(form.get("brandDescription") ?? "").trim();
  if (name.length < 2 || name.length > 120 || description.length < 2 || description.length > 2000
    || form.get("confirmPrototype") !== "yes") redirect("/open-brand?error=input");
  let failure: string | null = null;
  try {
    const db = await createClient();
    const { data, error } = await db.rpc("open_my_brand", { p_name: name, p_description: description });
    if (error || !data) failure = error?.code === "PGRST202" ? "migration" : error?.code === "42501" ? "membership" : "save";
  } catch { failure = "save"; }
  if (failure) redirect(`/open-brand?error=${failure}`);
  revalidatePath("/", "layout");
  redirect("/brand?success=1");
}
