// The root of the website: fonts, global CSS, page title.
import type { Metadata } from "next";
import { Cairo, Geist_Mono } from "next/font/google";
import "./globals.css";

// Cairo: the font of the LOOZ app (Arabic + Latin), the same on the dashboard.
const cairo = Cairo({
  variable: "--font-cairo",
  subsets: ["latin", "arabic"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "LOOZ · Administration",
  description: "Tableau de bord des administrateurs de LOOZ",
  icons: { icon: "/looz_logo.png" },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="fr"
      className={`${cairo.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full bg-looz-cream font-sans text-slate-900">{children}</body>
    </html>
  );
}
