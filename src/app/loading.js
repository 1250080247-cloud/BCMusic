export default function Loading() {
  return (
    <main className="app-shell relative pb-44">
      {/* Header Skeleton */}
      <header className="mx-auto max-w-4xl px-4 pb-6 pt-10 sm:px-8">
        {/* Logo */}
        <div className="mb-8 flex items-center justify-center gap-3">
          <div className="skeleton-pulse h-12 w-12 rounded-2xl" />
          <div className="flex flex-col gap-1">
            <div className="skeleton-pulse h-3 w-20 rounded-full" />
            <div className="skeleton-pulse h-6 w-28 rounded-full" />
          </div>
        </div>

        {/* Search Bar */}
        <div className="mx-auto mb-6 flex max-w-xl gap-3">
          <div className="skeleton-pulse h-12 flex-1 rounded-2xl" />
          <div className="skeleton-pulse h-12 w-24 rounded-2xl" />
        </div>

        {/* Category Pills */}
        <div className="flex gap-3 overflow-hidden">
          {Array.from({ length: 7 }).map((_, i) => (
            <div
              key={i}
              className="skeleton-pulse h-10 flex-shrink-0 rounded-full"
              style={{ width: `${70 + Math.random() * 40}px` }}
            />
          ))}
        </div>
      </header>

      {/* Ranking Skeleton */}
      <section className="mx-auto mb-10 max-w-5xl px-4 sm:px-8">
        <div className="mb-5 flex items-center gap-3">
          <div className="skeleton-pulse h-10 w-10 rounded-2xl" />
          <div className="flex flex-col gap-1">
            <div className="skeleton-pulse h-5 w-36 rounded-full" />
            <div className="skeleton-pulse h-3 w-48 rounded-full" />
          </div>
        </div>

        <div className="flex gap-4 overflow-hidden">
          {Array.from({ length: 6 }).map((_, i) => (
            <div
              key={i}
              className="flex-shrink-0 overflow-hidden rounded-2xl"
              style={{ width: '180px' }}
            >
              <div className="skeleton-pulse aspect-square w-full" />
            </div>
          ))}
        </div>
      </section>

      {/* Song List Skeleton */}
      <section className="mx-auto max-w-4xl px-4 sm:px-8">
        {/* Section Header */}
        <div className="mb-4 flex items-center gap-3">
          <div className="skeleton-pulse h-9 w-9 rounded-xl" />
          <div className="skeleton-pulse h-5 w-32 rounded-full" />
        </div>

        {/* Song Cards */}
        <div className="flex flex-col gap-4">
          {Array.from({ length: 5 }).map((_, i) => (
            <div
              key={i}
              className="surface-card flex items-center gap-4 rounded-2xl p-3"
              style={{ animationDelay: `${i * 80}ms` }}
            >
              <div className="skeleton-pulse h-16 w-16 flex-shrink-0 rounded-xl sm:h-20 sm:w-20" />
              <div className="flex flex-1 flex-col gap-2">
                <div className="skeleton-pulse h-4 w-3/4 rounded-full" />
                <div className="skeleton-pulse h-3 w-1/2 rounded-full" />
              </div>
              <div className="skeleton-pulse h-8 w-8 rounded-full" />
            </div>
          ))}
        </div>

        {/* Second Section Header */}
        <div className="mb-4 mt-10 flex items-center gap-3">
          <div className="skeleton-pulse h-9 w-9 rounded-xl" />
          <div className="skeleton-pulse h-5 w-28 rounded-full" />
        </div>

        {/* Second Song Cards */}
        <div className="flex flex-col gap-4">
          {Array.from({ length: 5 }).map((_, i) => (
            <div
              key={i}
              className="surface-card flex items-center gap-4 rounded-2xl p-3"
              style={{ animationDelay: `${(i + 5) * 80}ms` }}
            >
              <div className="skeleton-pulse h-16 w-16 flex-shrink-0 rounded-xl sm:h-20 sm:w-20" />
              <div className="flex flex-1 flex-col gap-2">
                <div className="skeleton-pulse h-4 w-2/3 rounded-full" />
                <div className="skeleton-pulse h-3 w-2/5 rounded-full" />
              </div>
              <div className="skeleton-pulse h-8 w-8 rounded-full" />
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}
