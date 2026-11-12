// Temporary content for pages that are not built yet.
export function EmptyPage({ title, description }: { title: string; description: string }) {
  return (
    <div>
      <h1 className="text-2xl font-bold text-slate-900">{title}</h1>
      <p className="mt-1 text-slate-500">{description}</p>
      <div className="mt-6 rounded-xl border border-dashed border-slate-300 bg-white p-10 text-center text-slate-400">
        Bientôt
      </div>
    </div>
  );
}
