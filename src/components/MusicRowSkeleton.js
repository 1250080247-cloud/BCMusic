export default function MusicRowSkeleton({ count = 5 }) {
  return (
    <div className="flex gap-4 overflow-hidden pb-2" aria-hidden="true">
      {Array.from({ length: count }, (_, index) => (
        <div key={index} className="horizontal-song-card shrink-0">
          <div className="horizontal-song-thumb skeleton-pulse" />
          <div className="skeleton-pulse mt-3 h-3 w-4/5 rounded" />
          <div className="skeleton-pulse mt-2 h-3 w-3/5 rounded" />
        </div>
      ))}
    </div>
  );
}
