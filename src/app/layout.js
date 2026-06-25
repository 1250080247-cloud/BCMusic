import { Geist, Geist_Mono } from "next/font/google";
import PersistentShell from "@/components/PersistentShell";
import SettingsBridge from "@/components/SettingsBridge";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata = {
  title: "BCMusic",
  description: "A smooth YouTube-powered music web app.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="vi" suppressHydrationWarning>
      <body
        className={`${geistSans.variable} ${geistMono.variable} min-h-full antialiased`}
        suppressHydrationWarning
      >
        <SettingsBridge />
        <PersistentShell>
          {children}
        </PersistentShell>
      </body>
    </html>
  );
}
