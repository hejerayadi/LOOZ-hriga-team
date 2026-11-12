// Dates, durations and numbers in French. Times are shown in Tunisia time.

const TZ = "Africa/Tunis";

const dayTime = new Intl.DateTimeFormat("fr-FR", {
  timeZone: TZ,
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});
const dayOnly = new Intl.DateTimeFormat("fr-FR", {
  timeZone: TZ,
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
});

/** "15/06/2026 11:00" */
export function dateTime(iso: string | null | undefined): string {
  return iso ? dayTime.format(new Date(iso)).replace(",", "") : "—";
}

const shortDayTime = new Intl.DateTimeFormat("fr-FR", {
  timeZone: TZ,
  day: "2-digit",
  month: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
});

/** "15/06 11:00" (no year: for tables) */
export function shortDateTime(iso: string | null | undefined): string {
  return iso ? shortDayTime.format(new Date(iso)).replace(",", "") : "—";
}

/** "09/02/2027" */
export function date(iso: string | null | undefined): string {
  return iso ? dayOnly.format(new Date(iso)) : "—";
}

/**
 * "à l'instant", "il y a 40 s", "il y a 4 min", "il y a 2 h", "il y a 3 j".
 * now = the server's time, moved by the time spent since it was received
 * (so a wrong clock on this computer changes nothing).
 */
export function timeAgo(iso: string | null | undefined, now: number): string {
  if (!iso) return "jamais";
  const s = Math.max(0, Math.round((now - new Date(iso).getTime()) / 1000));
  if (s < 10) return "à l'instant";
  if (s < 60) return `il y a ${s} s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `il y a ${m} min`;
  const h = Math.floor(m / 60);
  if (h < 48) return `il y a ${h} h`;
  return `il y a ${Math.floor(h / 24)} j`;
}

const one = new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 1 });
const two = new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 2 });

/** 23.4 -> "23,4" (null -> "—"). */
export function num(value: number | null | undefined, digits: 1 | 2 = 1): string {
  if (value === null || value === undefined) return "—";
  return (digits === 1 ? one : two).format(value);
}

/** "+21622777001" -> "+216 22 777 001" */
export function phone(value: string | null | undefined): string {
  if (!value) return "—";
  const m = value.match(/^\+216(\d{2})(\d{3})(\d{3})$/);
  return m ? `+216 ${m[1]} ${m[2]} ${m[3]}` : value;
}

/** Age of the trees from their planting year: "8 ans". */
export function age(plantedYear: number | null | undefined): string | null {
  if (!plantedYear) return null;
  const years = new Date().getFullYear() - plantedYear;
  return years <= 1 ? `${Math.max(years, 0)} an` : `${years} ans`;
}

/** "−82 dBm (bon)" */
export function signal(rssi: number | null | undefined): string {
  if (rssi === null || rssi === undefined) return "—";
  const quality = rssi >= -85 ? "bon" : rssi >= -100 ? "moyen" : "faible";
  return `${String(rssi).replace("-", "−")} dBm (${quality})`;
}

const dinars = new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 3 });

/** 414000 millimes -> "414 DT" */
export function money(millimes: number | null | undefined): string {
  if (millimes === null || millimes === undefined) return "—";
  return `${dinars.format(millimes / 1000)} DT`;
}
