const normalize = value => value.normalize('NFKD').replace(/\p{M}/gu, '').replace(/đ/gi, 'd').toLowerCase().replace(/\s+/g, ' ').trim();
const valid = value => typeof value === 'string' && value.trim() && value.length <= 160 && !/[\u0000-\u001f\u007f]/.test(value);

function uniqueSuggestions(values) {
  const seen = new Set();
  return values.filter(valid).filter(value => {
    const key = normalize(value);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).map(value => value.trim()).slice(0, 8);
}

export function mergeSearchSuggestions(query, history, remote) {
  const term = normalize(query);
  if (!term) return [];
  return uniqueSuggestions([
    ...(Array.isArray(history) ? history.filter(value => valid(value) && normalize(value).includes(term)) : []),
    ...(Array.isArray(remote) ? remote : []),
  ]);
}

export function parseSearchSuggestions(payload, query) {
  if (!Array.isArray(payload) || typeof payload[0] !== 'string' || payload[0].trim().toLowerCase() !== query.trim().toLowerCase() || !Array.isArray(payload[1])) throw new Error('invalid_suggestions_response');
  return uniqueSuggestions(payload[1].slice(0, 50));
}
