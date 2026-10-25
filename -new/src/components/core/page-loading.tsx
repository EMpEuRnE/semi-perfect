import { Container } from "@/components/ui/container";

export function PageLoading({ cards = 3 }: { cards?: number }) {
  return (
    <Container className="py-10 sm:py-14" aria-busy="true" aria-label="กำลังโหลดข้อมูล">
      <div className="h-3 w-28 animate-pulse rounded bg-slate-200" />
      <div className="mt-4 h-9 w-64 max-w-full animate-pulse rounded bg-slate-200" />
      <div className="mt-3 h-5 w-full max-w-xl animate-pulse rounded bg-slate-100" />
      <div className="mt-8 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: cards }, (_, index) => (
          <div key={index} className="h-64 animate-pulse rounded-3xl border border-slate-200 bg-white" />
        ))}
      </div>
      <span className="sr-only">กำลังโหลดข้อมูล...</span>
    </Container>
  );
}
