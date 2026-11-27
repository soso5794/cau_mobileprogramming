export class PlaceSearchError extends Error {
  constructor(status, code) { super(code); this.status = status; }
}

// The Geoapify key remains on the local Node server, independent of OpenAI.
export function createPlaceSearch({apiKey = process.env.GEOAPIFY_API_KEY || '', fetchImpl = fetch} = {}) {
  let active = 0, used = 0, windowStart = Date.now();
  return async function search(data) {
    const query = typeof data?.query === 'string' ? data.query.trim() : '';
    if (query.length < 2 || query.length > 120) throw new PlaceSearchError(400, 'INVALID_PLACE_QUERY');
    if (!apiKey.trim()) throw new PlaceSearchError(503, 'PLACE_KEY_REQUIRED');
    if (Date.now() - windowStart >= 60000) { used = 0; windowStart = Date.now(); }
    if (active >= 2 || used >= 20) throw new PlaceSearchError(429, 'PLACE_RATE_LIMITED');
    active++; used++;
    try {
      const url = new URL('https://api.geoapify.com/v1/geocode/search');
      url.search = new URLSearchParams({text: query, lang: 'ko', limit: '8', filter: 'countrycode:kr', format: 'json', apiKey});
      const response = await fetchImpl(url, {signal: AbortSignal.timeout(10000)});
      if (!response.ok) throw new PlaceSearchError(response.status === 429 ? 429 : [401,403].includes(response.status) ? 503 : 502, 'PLACE_PROVIDER_ERROR');
      const data = await response.json();
      if (!Array.isArray(data?.results)) throw new PlaceSearchError(502, 'INVALID_PLACE_RESPONSE');
      const results = [];
      for (const item of data.results.slice(0,8)) {
        if (!item || !Number.isFinite(item.lat) || !Number.isFinite(item.lon) || Math.abs(item.lat)>85.05112878 || Math.abs(item.lon)>180) continue;
        const name = [item.name,item.address_line1,item.formatted].find(v => typeof v === 'string' && v.trim())?.trim().slice(0,120);
        if (!name) continue;
        results.push({name, address: typeof item.formatted === 'string' ? item.formatted.trim().slice(0,300) : '', latitude:item.lat, longitude:item.lon});
      }
      return {results};
    } finally { active--; }
  };
}
