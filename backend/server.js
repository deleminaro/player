'use strict';

require('dotenv').config();

const express    = require('express');
const helmet     = require('helmet');
const rateLimit  = require('express-rate-limit');
const fetch      = require('node-fetch');

const app  = express();
const PORT = process.env.PORT || 3000;

// ─── Required env vars ───────────────────────────────────────────────────────
const REQUIRED = ['GENIUS_TOKEN', 'SOUNDCLOUD_CLIENT_ID', 'APP_API_KEY'];
for (const key of REQUIRED) {
    if (!process.env[key]) {
        console.error(`[startup] Missing required env var: ${key}`);
        process.exit(1);
    }
}

// ─── Security headers ────────────────────────────────────────────────────────
app.use(helmet());
app.use(express.json({ limit: '10kb' }));

// ─── Global rate limit: 200 req / 15 min per IP ──────────────────────────────
app.use(rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 200,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many requests, please slow down.' },
}));

// Stricter limit for search endpoints: 60 req / min per IP
const searchLimit = rateLimit({
    windowMs: 60 * 1000,
    max: 60,
    message: { error: 'Search rate limit exceeded.' },
});

// ─── App authentication middleware ───────────────────────────────────────────
// The iOS app sends  X-App-Key: <APP_API_KEY>  on every request.
// This key is loaded from xcconfig / Info.plist on the device.
// It is NOT a user secret — it just prevents random internet traffic
// from hitting your proxy. Rotate it if compromised (no app update needed).
function requireAppKey(req, res, next) {
    const key = req.headers['x-app-key'];
    if (!key || key !== process.env.APP_API_KEY) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
}

// Apply app-key check to all /api routes
app.use('/api', requireAppKey);

// ─── Health check (no auth needed) ──────────────────────────────────────────
app.get('/health', (_, res) => res.json({ ok: true }));

// ─── Genius: lyrics search ───────────────────────────────────────────────────
// GET /api/genius/search?q=track+title+artist
app.get('/api/genius/search', searchLimit, async (req, res) => {
    const q = (req.query.q || '').trim();
    if (!q || q.length > 200) {
        return res.status(400).json({ error: 'Invalid query' });
    }

    try {
        const url = `https://api.genius.com/search?q=${encodeURIComponent(q)}`;
        const response = await fetch(url, {
            headers: { Authorization: `Bearer ${process.env.GENIUS_TOKEN}` },
            signal: AbortSignal.timeout(8000),
        });

        if (!response.ok) {
            return res.status(response.status).json({ error: 'Genius API error' });
        }

        const data = await response.json();

        // Return only the fields the iOS app needs — don't forward raw tokens etc.
        const hits = (data?.response?.hits || [])
            .filter(h => h.type === 'song')
            .slice(0, 5)
            .map(h => ({
                title:   h.result.title,
                artist:  h.result.primary_artist.name,
                url:     h.result.url,            // Genius lyrics page URL
                artwork: h.result.song_art_image_thumbnail_url,
            }));

        res.json({ hits });
    } catch (err) {
        console.error('[genius]', err.message);
        res.status(502).json({ error: 'Failed to reach Genius' });
    }
});

// ─── SoundCloud: search tracks ────────────────────────────────────────────────
// GET /api/soundcloud/search?q=query&offset=0&limit=20
app.get('/api/soundcloud/search', searchLimit, async (req, res) => {
    const q      = (req.query.q || '').trim();
    const offset = Math.max(0, Math.min(990, parseInt(req.query.offset) || 0));
    const limit  = Math.max(1, Math.min(50,  parseInt(req.query.limit)  || 20));

    if (!q || q.length > 200) {
        return res.status(400).json({ error: 'Invalid query' });
    }

    try {
        const params = new URLSearchParams({
            q, limit: String(limit), offset: String(offset),
            client_id: process.env.SOUNDCLOUD_CLIENT_ID,
        });
        const response = await fetch(
            `https://api-v2.soundcloud.com/search/tracks?${params}`,
            { signal: AbortSignal.timeout(10000) }
        );

        if (!response.ok) {
            return res.status(response.status).json({ error: 'SoundCloud API error' });
        }

        const data = await response.json();
        res.json(data);          // forward the full SC response
    } catch (err) {
        console.error('[soundcloud]', err.message);
        res.status(502).json({ error: 'Failed to reach SoundCloud' });
    }
});

// ─── SoundCloud: resolve stream URL ──────────────────────────────────────────
// GET /api/soundcloud/stream?url=<transcoding_url>
app.get('/api/soundcloud/stream', async (req, res) => {
    const transcodeURL = (req.query.url || '').trim();

    // Only allow SoundCloud transcoding URLs
    if (!transcodeURL.startsWith('https://api-v2.soundcloud.com/media/soundcloud:tracks:')) {
        return res.status(400).json({ error: 'Invalid transcoding URL' });
    }

    try {
        const response = await fetch(
            `${transcodeURL}?client_id=${process.env.SOUNDCLOUD_CLIENT_ID}`,
            { signal: AbortSignal.timeout(8000) }
        );
        if (!response.ok) return res.status(response.status).json({ error: 'SC stream error' });
        const data = await response.json();
        // Return only the CDN stream URL — client_id never leaves the server
        res.json({ url: data.url });
    } catch (err) {
        console.error('[sc-stream]', err.message);
        res.status(502).json({ error: 'Failed to resolve stream' });
    }
});

// ─── 404 catch-all ───────────────────────────────────────────────────────────
app.use((_, res) => res.status(404).json({ error: 'Not found' }));

// ─── Start ───────────────────────────────────────────────────────────────────
app.listen(PORT, () => console.log(`[server] listening on :${PORT}`));
