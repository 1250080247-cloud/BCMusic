import { Suspense } from 'react';
import { SongRowSection } from "@/components/DualViewSection";
import GenreExplorer from "@/components/GenreExplorer";
import HomeEmptyState from "@/components/HomeEmptyState";
import HomeHeader from "@/components/HomeHeader";
import PaginationControls from "@/components/PaginationControls";
import RankingSection from "@/components/RankingSection";
import SongCard from "@/components/SongCard";
import { getYouTubeSongs } from "@/lib/youtube";

// The category URL is dynamic; MongoDB caches each feed for one hour.
export const revalidate = 1800;

async function LoadedRanking({ result, genreKey }) {
  const data = await result;
  return <RankingSection songs={data.items} genreKey={genreKey} />;
}

async function LoadedRow({ result, genreKey, kind }) {
  const data = await result;
  return <SongRowSection songs={data.items} genreKey={genreKey} kind={kind} />;
}

async function LoadedPagination({ result, currentQuery }) {
  const data = await result;
  return <PaginationControls currentQuery={currentQuery} prevPageToken={data.prevPageToken} nextPageToken={data.nextPageToken} />;
}

const categories = [
  { key: "tiktokRemix", query: "tiktok remix" },
  { key: "chineseMusic", query: "nhạc trung douyin" },
  { key: "lofi", query: "lofi chill vietnamese" },
  { key: "edm", query: "edm ncs" },
  { key: "acoustic", query: "nhạc acoustic nhẹ nhàng" },
  { key: "kpop", query: "kpop hit" },
  { key: "rapViet", query: "rap việt hot" },
  { key: "rnb", query: "rnb soul" },
  { key: "piano", query: "piano instrumental relaxing" },
  { key: "popHits", query: "pop hits 2024 2025" },
];

export default async function Home({ searchParams }) {
  const resolvedParams = await searchParams;
  const genreParam = Array.isArray(resolvedParams.genre) ? resolvedParams.genre[0] : resolvedParams.genre;
  const tokenParam = Array.isArray(resolvedParams.token) ? resolvedParams.token[0] : resolvedParams.token;
  const searchParam = Array.isArray(resolvedParams.search) ? resolvedParams.search[0] : resolvedParams.search;

  const currentSearch = searchParam ? searchParam.trim() : "";
  const currentQuery = genreParam === 'tiktok remix ncs' ? categories[0].query : genreParam || categories[0].query;
  const genreKey = categories.find(category => category.query === currentQuery)?.key;
  const currentToken = tokenParam || "";

  const isSearchMode = Boolean(currentSearch);

  let searchSongs = [];
  let searchNextToken = null;
  let searchPrevToken = null;
  let mostViewedResult;
  let newestResult;
  let rankingResult;

  if (isSearchMode) {
    // Search mode: sort by relevance so newer songs also appear
    const result = await getYouTubeSongs(currentSearch, currentToken, "relevance");
    searchSongs = result.items;
    searchNextToken = result.nextPageToken;
    searchPrevToken = result.prevPageToken;
  } else {
    // Start all feeds together, then stream each without waiting for the slowest.
    [mostViewedResult, newestResult, rankingResult] = [
      getYouTubeSongs(currentQuery, currentToken, "viewCount", 5),
      getYouTubeSongs(currentQuery, "", "date", 5),
      currentToken ? null : getYouTubeSongs(`${currentQuery} trending`, "", "relevance", 10),
    ];
  }

  return (
    <main className="app-shell relative pb-8">
      <HomeHeader
        categories={categories}
        currentQuery={currentQuery}
        currentSearch={currentSearch}
      />

      {/* Ranking — only when not searching and on first page */}
      {!isSearchMode && !currentToken && (
        <Suspense key={`ranking:${currentQuery}`} fallback={<RankingSection songs={[]} genreKey={genreKey} isLoading />}>
          <LoadedRanking result={rankingResult} genreKey={genreKey} />
        </Suspense>
      )}

      <section className="mx-auto px-4 sm:px-8" style={{ maxWidth: '80rem' }}>
        {isSearchMode ? (
          <>

            {searchSongs.length === 0 ? (
              <HomeEmptyState />
            ) : (
              <div className="flex flex-col gap-4">
                {searchSongs.map((song) => (
                  <SongCard key={song.id} song={song} playlist={searchSongs} />
                ))}
              </div>
            )}

            <PaginationControls
              currentQuery={currentQuery}
              currentSearch={currentSearch}
              prevPageToken={searchPrevToken}
              nextPageToken={searchNextToken}
            />
          </>
        ) : (
          <>
            <div className="flex flex-col gap-8">
              <Suspense key={`mostViewed:${currentQuery}:${currentToken}`} fallback={<SongRowSection songs={[]} genreKey={genreKey} kind="mostViewed" isLoading />}>
                <LoadedRow result={mostViewedResult} genreKey={genreKey} kind="mostViewed" />
              </Suspense>
              <Suspense key={`newest:${currentQuery}`} fallback={<SongRowSection songs={[]} genreKey={genreKey} kind="newest" isLoading />}>
                <LoadedRow result={newestResult} genreKey={genreKey} kind="newest" />
              </Suspense>
            </div>
            <Suspense key={`pagination:${currentQuery}:${currentToken}`} fallback={null}>
              <LoadedPagination result={mostViewedResult} currentQuery={currentQuery} />
            </Suspense>
          </>
        )}
      </section>

      {/* Genre Explorer + Footer — always visible */}
      <GenreExplorer />
    </main>
  );
}
