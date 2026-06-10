import HomeEmptyState from "@/components/HomeEmptyState";
import HomeHeader from "@/components/HomeHeader";
import PaginationControls from "@/components/PaginationControls";
import Player from "@/components/Player";
import SongCard from "@/components/SongCard";
import SongModal from "@/components/SongModal";

const categories = [
  { key: "tiktokRemix", query: "tiktok remix ncs" },
  { key: "chineseMusic", query: "nhạc trung douyin" },
  { key: "lofi", query: "lofi chill vietnamese" },
  { key: "edm", query: "edm ncs" },
  { key: "acoustic", query: "nhạc acoustic nhẹ nhàng" },
];

async function getYouTubeSongs(searchQuery, pageToken = "") {
  const API_KEY = process.env.YOUTUBE_API_KEY;
  if (!API_KEY) return { items: [], nextPageToken: null, prevPageToken: null };

  const tokenParam = pageToken ? `&pageToken=${pageToken}` : "";
  const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=5&q=${encodeURIComponent(searchQuery)}&type=video&key=${API_KEY}${tokenParam}`;

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
  const currentQuery = genreParam || categories[0].query;
  const currentToken = tokenParam || "";
  const { items: songs, nextPageToken, prevPageToken } = await getYouTubeSongs(currentQuery, currentToken);

  return (
    <main className="app-shell relative pb-32">
      <HomeHeader categories={categories} currentQuery={currentQuery} />

      <section className="mx-auto max-w-4xl px-4 sm:px-8">
        {songs.length === 0 ? (
          <HomeEmptyState />
        ) : (
          <div className="flex flex-col gap-4">
            {songs.map((song) => (
              <SongCard key={song.id} song={song} playlist={songs} />
            ))}
          </div>
        )}

        <PaginationControls
          currentQuery={currentQuery}
          prevPageToken={prevPageToken}
          nextPageToken={nextPageToken}
        />
      </section>

      <Player />
      <SongModal />
    </main>
  );
}
