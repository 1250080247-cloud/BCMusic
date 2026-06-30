"use client";

import Image from 'next/image';
import Link from 'next/link';
import { Clock, Settings } from 'lucide-react';
import CategoryScroller from '@/components/CategoryScroller';
import SettingsPanel from '@/components/SettingsPanel';
import AuthModal from '@/components/AuthModal';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

function getGreeting(language) {
  const hour = new Date().getHours();
  if (language === 'vi') {
    if (hour < 12) return 'Chào buổi sáng';
    if (hour < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }
  if (hour < 12) return 'Good Morning';
  if (hour < 18) return 'Good Afternoon';
  return 'Good Evening';
}

export default function HomeHeader({ categories, currentQuery, currentSearch }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);
  const greeting = getGreeting(language);

  return (
    <header className="home-header">
      <div className="home-header-inner">
        {/* Left: Logo + Brand */}
        <div className="home-header-brand">
          <Link href="/" className="home-header-logo">
            <Image
              src="/logo.jpg"
              alt="BCMusic Logo"
              width={40}
              height={40}
              className="h-full w-full object-cover"
            />
          </Link>
          <div className="home-header-brand-text">
            <h1 className="home-header-title">{t.common.brand}</h1>
            <p className="home-header-greeting">{greeting}</p>
          </div>
        </div>

        {/* Right: Action icons */}
        <div className="home-header-actions">
          <Link
            href="/history"
            className="home-header-icon-btn"
            aria-label={t.common.history}
            title={t.common.history}
          >
            <Clock size={20} />
          </Link>
          <div className="md:hidden header-auth-wrapper">
            <AuthModal />
          </div>
          <SettingsPanel />
        </div>
      </div>

      {/* Category Pills */}
      {!currentSearch && (
        <div className="home-header-categories">
          <CategoryScroller categories={categories} currentQuery={currentQuery} />
        </div>
      )}
    </header>
  );
}
