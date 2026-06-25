"use client";

import { Home, Library, Search, CloudDownload } from 'lucide-react';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

const sidebarItems = [
  { key: 'home', href: '/', icon: Home },
  { key: 'search', href: '/search', icon: Search },
  { key: 'library', href: '/history', icon: Library },
  { key: 'soundcloud', href: '/soundcloud', icon: CloudDownload },
];

export default function Sidebar() {
  const pathname = usePathname();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  const isActive = (href) => {
    if (href === '/') return pathname === '/' || pathname === '';
    return pathname === href;
  };

  return (
    <nav className="sidebar" aria-label="Main navigation">
      {/* Logo */}
      <Link href="/" className="sidebar-logo">
        <div className="sidebar-logo-img">
          <Image
            src="/logo.jpg"
            alt="BCMusic Logo"
            width={36}
            height={36}
            className="h-full w-full object-cover"
          />
        </div>
      </Link>

      {/* Nav Items */}
      <div className="sidebar-nav-items">
        {sidebarItems.map((item) => {
          const Icon = item.icon;
          const active = isActive(item.href);

          return (
            <Link
              key={item.key}
              href={item.href}
              className={`sidebar-nav-item ${active ? 'is-active' : ''}`}
            >
              <Icon size={22} strokeWidth={active ? 2.2 : 1.6} />
              <span className="sidebar-nav-label">{t.sidebar[item.key]}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
