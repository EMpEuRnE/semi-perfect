import type { Metadata } from "next";
import { AuthCard } from "@/components/auth/auth-card";

export const metadata: Metadata = { title: "สมัครสมาชิก" };

export default function RegisterPage({ searchParams }: { searchParams?: Promise<Record<string, string | string[] | undefined>> }) {
  return <AuthCard mode="register" searchParams={searchParams} />;
}
