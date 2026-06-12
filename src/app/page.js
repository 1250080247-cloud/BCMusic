import BottomNav from "@/components/BottomNav";
import DualViewSection from "@/components/DualViewSection";
import HomeEmptyState from "@/components/HomeEmptyState";
import HomeHeader from "@/components/HomeHeader";
import PaginationControls from "@/components/PaginationControls";
import Player from "@/components/Player";
import RankingSection from "@/components/RankingSection";
import SongCard from "@/components/SongCard";
import SongModal from "@/components/SongModal";

const categories = [
  { key: "tiktokRemix", query: "tiktok remix ncs" },
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

async function getYouTubeSongs(searchQuery, pageToken = "", order = "relevance", maxResults = 5) {
  const API_KEY = process.env.YOUTUBE_API_KEY;
  if (!API_KEY) return { items: [], nextPageToken: null, prevPageToken: null };

  const tokenParam = pageToken ? `&pageToken=${pageToken}` : "";
  const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=${maxResults}&q=${encodeURIComponent(searchQuery)}&type=video&order=${order}&key=${API_KEY}${tokenParam}`;

  try {
    const res = await fetch(url, { cache: "no-store" });
    const data = await res.json();

    if (!res.ok) {
      console.error("YouTube API Error:", data.error?.message);
      return { items: [], nextPageToken: null, prevPageToken: null };
    }

    const formattedItems = (data.items || [])
      .filter((item) => item.id?.videoId)
      .map((item) => ({
        id: item.id.videoId,
        title: item.snippet.title,
        artist: item.snippet.channelTitle,
        thumbnail: item.snippet.thumbnails.high?.url || item.snippet.thumbnails.medium?.url,
        publishedAt: item.snippet.publishedAt,
      }));

    return {
      items: formattedItems,
      nextPageToken: data.nextPageToken || null,
      prevPageToken: data.prevPageToken || null,
    };
  } catch (error) {
    console.error("Fetch Error:", error);
    return { items: [], nextPageToken: null, prevPageToken: null };
  }
}

export default async function Home({ searchParams }) {
  const resolvedParams = await searchParams;
  const genreParam = Array.isArray(resolvedParams.genre) ? resolvedParams.genre[0] : resolvedParams.genre;
  const tokenParam = Array.isArray(resolvedParams.token) ? resolvedParams.token[0] : resolvedParams.token;
  const searchParam = Array.isArray(resolvedParams.search) ? resolvedParams.search[0] : resolvedParams.search;

  const currentSearch = searchParam ? searchParam.trim() : "";
  const currentQuery = genreParam || categories[0].query;
  const currentToken = tokenParam || "";

  const isSearchMode = Boolean(currentSearch);

  let searchSongs = [];
  let searchNextToken = null;
  let searchPrevToken = null;
  let mostViewedSongs = [];
  let newestSongs = [];
  let rankingSongs = [];

  if (isSearchMode) {
    // Search mode: sort by view count to show most popular first
    const result = await getYouTubeSongs(currentSearch, currentToken, "viewCount");
    searchSongs = result.items;
    searchNextToken = result.nextPageToken;
    searchPrevToken = result.prevPageToken;
  } else {
    // Category mode: fetch most viewed + newest in parallel, plus ranking
    const [mostViewedResult, newestResult, rankingResult] = await Promise.all([
      getYouTubeSongs(currentQuery, currentToken, "viewCount", 5),
      getYouTubeSongs(currentQuery, "", "date", 5),
      currentToken ? Promise.resolve({ items: [] }) : getYouTubeSongs("music trending", "", "viewCount", 10),
    ]);

    mostViewedSongs = mostViewedResult.items;
    searchNextToken = mostViewedResult.nextPageToken;
    searchPrevToken = mostViewedResult.prevPageToken;
    newestSongs = newestResult.items;
    rankingSongs = rankingResult.items;
  }

  return (
    <main className="app-shell relative pb-44">
      <HomeHeader
        categories={categories}
        currentQuery={currentQuery}
        currentSearch={currentSearch}
      />

      {/* Ranking — only when not searching and on first page */}
      {!isSearchMode && !currentToken && rankingSongs.length > 0 && (
        <RankingSection songs={rankingSongs} />
      )}

      <section className="mx-auto max-w-4xl px-4 sm:px-8">
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
            {/* Dual View: Most Viewed + Newest */}
            {mostViewedSongs.length === 0 && newestSongs.length === 0 ? (
              <HomeEmptyState />
            ) : (
              <DualViewSection
                mostViewedSongs={mostViewedSongs}
                newestSongs={newestSongs}
              />
            )}

            <PaginationControls
              currentQuery={currentQuery}
              prevPageToken={searchPrevToken}
              nextPageToken={searchNextToken}
            />
          </>
        )}
      </section>

      <Player />
      <SongModal />
      <BottomNav />
    </main>
  );
}
