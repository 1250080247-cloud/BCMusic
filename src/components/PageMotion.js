"use client";

import { useRef } from 'react';
import { usePathname } from 'next/navigation';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

if (typeof window !== 'undefined') gsap.registerPlugin(useGSAP, ScrollTrigger);

export default function PageMotion({ children }) {
  const root = useRef(null);
  const pathname = usePathname();

  useGSAP(() => {
    const media = gsap.matchMedia();
    media.add('(prefers-reduced-motion: no-preference)', () => {
      const intro = root.current.querySelectorAll('h1, [data-motion-intro]');
      if (intro.length) {
        gsap.fromTo(intro, { opacity: 0, y: 12 }, {
          opacity: 1, y: 0, duration: 0.45, stagger: 0.055,
          ease: 'power2.out', clearProps: 'opacity,transform',
        });
      }
      root.current.querySelectorAll('[data-motion-section]').forEach((section) => {
        gsap.fromTo(section, { opacity: 0, y: 20 }, {
          opacity: 1, y: 0, duration: 0.55, ease: 'power2.out',
          immediateRender: false,
          clearProps: 'opacity,transform',
          scrollTrigger: { trigger: section, start: 'top 92%', once: true },
        });
      });
    });
    return () => media.revert();
  }, { scope: root, dependencies: [pathname, children], revertOnUpdate: true });

  return <div ref={root}>{children}</div>;
}
