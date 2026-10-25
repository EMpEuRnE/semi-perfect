import type { Metadata } from "next";
import { AuthCard } from "@/components/auth/auth-card";

export const metadata: Metadata = { title: "เข้าสู่ระบบ" };

export default function LoginPage({ searchParams }: { searchParams?: Promise<Record<string, string | string[] | undefined>> }) {
  return <AuthCard mode="login" searchParams={searchParams} />;
}
