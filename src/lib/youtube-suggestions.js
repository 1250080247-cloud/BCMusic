import { readJsonResponse } from './read-json-response';
import { parseSearchSuggestions } from './search-suggestions';

export async function getSearchSuggestions(query, language = 'vi') {
  const url = new URL('https://www.google.com/complete/search');
  url.search = new URLSearchParams({ client: 'firefox', ds: 'yt', hl: language, gl: language === 'vi' ? 'VN' : 'US', q: query }).toString();
  const response = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(2500), next: { revalidate: 300 } });
  if (!response.ok) throw new Error('suggestions_unavailable');
  return parseSearchSuggestions(await readJsonResponse(response, 65536), query);
}
