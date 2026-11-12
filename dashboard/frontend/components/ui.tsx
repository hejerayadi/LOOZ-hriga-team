"use client";

// Small pieces used by every page: card, number, dialog, tabs, buttons,
// error and empty messages. Same look everywhere (texts in French).
import { useEffect, useId, useRef } from "react";

export function Card({
  title,
  children,
  className = "",
  action,
}: {
  title: string;
  children: React.ReactNode;
  className?: string;
  action?: React.ReactNode;
}) {
  return (
    <section className={`rounded-xl border border-slate-200 bg-white p-5 ${className}`}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-500">{title}</h2>
        {action}
      </div>
      <div className="mt-3">{children}</div>
    </section>
  );
}

export function Fact({ name, value }: { name: string; value: React.ReactNode }) {
  return (
    <div>
      <div className="text-xs text-slate-500">{name}</div>
      <div className="text-lg font-semibold text-slate-900">{value}</div>
    </div>
  );
}

const BUTTON = {
  primary: "bg-emerald-700 text-white hover:bg-emerald-800 disabled:opacity-60",
  danger: "bg-rose-700 text-white hover:bg-rose-800 disabled:opacity-60",
  plain: "border border-slate-300 bg-white text-slate-700 hover:bg-slate-100 disabled:opacity-60",
};

export function Button({
  kind = "plain",
  small = false,
  className = "",
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { kind?: keyof typeof BUTTON; small?: boolean }) {
  return (
    <button
      type="button"
      {...props}
      className={`rounded-lg font-medium ${small ? "px-2.5 py-1 text-xs" : "px-4 py-2 text-sm"} ${BUTTON[kind]} ${className}`}
    />
  );
}

/** A red message with "Réessayer". */
export function ErrorBox({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div role="alert" className="flex flex-wrap items-center gap-3 rounded-lg bg-red-50 px-4 py-2 text-sm text-red-700">
      {message}
      {onRetry && (
        <button type="button" onClick={onRetry} className="font-medium underline">
          Réessayer
        </button>
      )}
    </div>
  );
}

export function Empty({ children }: { children: React.ReactNode }) {
  return <p className="rounded-lg border border-dashed border-slate-300 px-4 py-6 text-center text-sm text-slate-500">{children}</p>;
}

/** "Démo" next to a demo account, orchard or line of the log. */
export function DemoTag() {
  return (
    <span className="rounded bg-violet-50 px-1.5 py-0.5 text-[11px] font-medium text-violet-800 ring-1 ring-violet-200">démo</span>
  );
}

/**
 * A window over the page. Escape or "Annuler" closes it (not while busy).
 * The first field (or button) gets the focus.
 */
export function Dialog({
  title,
  children,
  onClose,
  busy = false,
  wide = false,
}: {
  title: string;
  children: React.ReactNode;
  onClose: () => void;
  busy?: boolean;
  wide?: boolean;
}) {
  const titleId = useId();
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const first = box.current?.querySelector<HTMLElement>("input, textarea, select, button[data-autofocus]");
    first?.focus();
  }, []);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape" && !busy) onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [busy, onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4" onMouseDown={() => !busy && onClose()}>
      <div
        ref={box}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onMouseDown={(e) => e.stopPropagation()}
        className={`max-h-[90vh] w-full overflow-y-auto rounded-2xl bg-white p-6 shadow-xl ${wide ? "max-w-2xl" : "max-w-md"}`}
      >
        <h2 id={titleId} className="text-lg font-bold text-slate-900">
          {title}
        </h2>
        <div className="mt-3 text-sm text-slate-700">{children}</div>
      </div>
    </div>
  );
}

/** The input of a reason (3 to 300 letters), with its counter. */
export function ReasonField({
  value,
  onChange,
  required,
  label = "Motif",
  placeholder = "Expliquez en quelques mots",
}: {
  value: string;
  onChange: (v: string) => void;
  required: boolean;
  label?: string;
  placeholder?: string;
}) {
  const n = value.trim().length;
  return (
    <label className="mt-4 block font-medium text-slate-700">
      {label} {required ? <span className="text-rose-700">(obligatoire)</span> : <span className="font-normal text-slate-500">(facultatif)</span>}
      <textarea
        value={value}
        onChange={(e) => onChange(e.target.value)}
        maxLength={300}
        rows={3}
        placeholder={placeholder}
        className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 font-normal outline-none focus:border-emerald-600 focus:ring-2 focus:ring-emerald-100"
      />
      <span className="block text-right text-xs font-normal text-slate-400">{n} / 300</span>
    </label>
  );
}

/** A reason is fine: 3 to 300 letters, no < > (same rule as the database). */
export function reasonOk(value: string): boolean {
  const v = value.trim();
  return v.length >= 3 && v.length <= 300 && !/[<>]/.test(v);
}

export function Tabs<T extends string>({
  tabs,
  current,
  onChange,
}: {
  tabs: { id: T; label: string; count?: number }[];
  current: T;
  onChange: (id: T) => void;
}) {
  return (
    <div role="tablist" className="flex flex-wrap gap-1 border-b border-slate-200">
      {tabs.map((t) => (
        <button
          key={t.id}
          type="button"
          role="tab"
          aria-selected={current === t.id}
          onClick={() => onChange(t.id)}
          className={
            "-mb-px rounded-t-lg border-b-2 px-4 py-2 text-sm font-medium " +
            (current === t.id ? "border-emerald-700 text-emerald-800" : "border-transparent text-slate-500 hover:text-slate-800")
          }
        >
          {t.label}
          {t.count !== undefined && (
            <span className={`ml-2 rounded-full px-2 py-0.5 text-xs ${current === t.id ? "bg-emerald-50" : "bg-slate-100"}`}>{t.count}</span>
          )}
        </button>
      ))}
    </div>
  );
}
