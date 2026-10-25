import Link from "next/link";
import { ShieldAlert } from "lucide-react";
import { Container } from "@/components/ui/container";
import { Card } from "@/components/ui/card";
import { buttonLinkClass } from "@/components/ui/button";

type UnauthorizedPageProps = {
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function UnauthorizedPage({ searchParams }: UnauthorizedPageProps) {
  const params = await searchParams;
  const required = params?.required;
  const requiredLabel = required === "admin" ? "ผู้ดูแลระบบ" : required === "brand" ? "แบรนด์" : "";

  return (
    <Container className="grid min-h-[70svh] place-items-center py-12">
      <Card className="w-full max-w-xl p-7 text-center sm:p-10">
        <div className="mx-auto flex size-14 items-center justify-center rounded-2xl bg-amber-50 text-amber-800">
          <ShieldAlert size={26} aria-hidden="true" />
        </div>
        <h1 className="mt-5 text-2xl font-semibold tracking-tight text-slate-950">ไม่มีสิทธิ์เข้าถึงหน้านี้</h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">
          {requiredLabel
            ? `หน้านี้สำหรับบัญชี${requiredLabel}เท่านั้น หากคิดว่าเป็นข้อผิดพลาด โปรดติดต่อผู้ดูแลระบบของ Move & Earn`
            : "บัญชีของคุณไม่มีสิทธิ์สำหรับเนื้อหานี้"}
        </p>
        {required === "brand" && <Link href="/open-brand" className="mt-5 block font-semibold text-emerald-800 underline">เปิดบัญชีแบรนด์ / ตรวจสิทธิ์บัญชีเดิม</Link>}
        <Link href="/" className={`${buttonLinkClass("secondary")} mt-6`}>
          กลับหน้าแรก
        </Link>
      </Card>
    </Container>
  );
}
