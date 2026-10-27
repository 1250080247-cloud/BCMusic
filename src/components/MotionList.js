"use client";

import { useRef } from 'react';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';

if (typeof window !== 'undefined') gsap.registerPlugin(useGSAP);

export default function MotionList({ children, className, style, animationKey }) {
  const root = useRef(null);

  useGSAP(() => {
    const media = gsap.matchMedia();
    media.add('(prefers-reduced-motion: no-preference)', () => {
      const items = Array.from(root.current.children);
      if (!items.length) return;
      // Leave transforms to the existing hover styles and playback controls.
      gsap.fromTo(items, { opacity: 0 }, {
        opacity: 1, duration: 0.35, stagger: { amount: 0.24 },
        ease: 'power1.out', clearProps: 'opacity',
      });
    });
    return () => media.revert();
  }, { scope: root, dependencies: [animationKey], revertOnUpdate: true });

  return <div ref={root} className={className} style={style}>{children}</div>;
}
