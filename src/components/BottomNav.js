"use client";

import { Home, Library, ListMusic } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

const navItems = [
  { key: 'home', href: '/', icon: Home },
  { key: 'library', href: '/history', icon: Library },
  { key: 'playlist', href: '/playlist', icon: ListMusic },
];

export default function BottomNav() {
  const pathname = usePathname();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  return (
    <nav className="bottom-nav fixed bottom-0 left-0 right-0 z-40">
      <div className="mx-auto flex max-w-screen-xl items-center justify-around">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = pathname === item.href;

          return (
            <Link
              key={item.key}
              href={item.href}
              className={`bottom-nav-item ${isActive ? 'is-active' : ''}`}
            >
              <Icon size={22} strokeWidth={isActive ? 2.2 : 1.6} />
              <span className="text-[11px] font-semibold">{t.bottomNav[item.key]}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
