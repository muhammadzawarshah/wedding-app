# Wedding live streaming

The app + website play **any** stream URL you put in the admin (HLS `.m3u8`,
YouTube, Vimeo, or an MP4). This folder is the **self-hosted, free** way to
produce that stream yourself and keep the recording.

How it fits together:

```
 Broadcaster                MediaMTX (this folder)            Viewers
 OBS / phone   --RTMP-->   ingest :1935                       Website  (hls.js)
 (couple)                  republish as HLS :8888  -------->  Flutter app (video_player)
                           record -> ./recordings             Guests
```

## 1. Start the streaming server

```bash
cd streaming
docker compose up -d
```

This runs MediaMTX:
- **RTMP ingest:** `rtmp://<SERVER-IP>:1935/live`
- **HLS playback:** `http://<SERVER-IP>:8888/live/index.m3u8`
- **Recordings:** saved to `streaming/recordings/live/…` as `.mp4`

`<SERVER-IP>` = the LAN IP of the PC running Docker (e.g. `192.168.1.7`), or a
public domain/IP if guests are remote (see step 4).

## 2. Go live (broadcast)

**From a laptop (OBS Studio):** Settings → Stream →
- Service: `Custom`
- Server: `rtmp://<SERVER-IP>:1935/live`
- Stream Key: *(leave empty)*

Click **Start Streaming**.

**From a phone:** use any RTMP broadcaster app (e.g. *Larix Broadcaster*) with
URL `rtmp://<SERVER-IP>:1935/live`.

## 3. Show it in the app + website

In the website **/admin → Wedding settings**:
1. **Live stream URL** = `http://<SERVER-IP>:8888/live/index.m3u8`
2. **Live now** = `🔴 LIVE now`
3. Save.

Now a **LIVE NOW** banner appears on the website and the app's **Live Stream**
screen plays it in-app. Toggle back to **Not live** when finished.

> Per-event streaming works the same way: paste the HLS/YouTube URL into an
> event's **Live stream link** and flip **Live now** on that event.

## 4. Letting remote guests watch

The LAN IP only works on the same Wi‑Fi. For guests on the internet you need a
public, preferably HTTPS, address (a website served over HTTPS can only load an
HTTPS stream). Easiest options:

- **Cloudflare Tunnel** (free): `cloudflared tunnel --url http://localhost:8888`
  → use the generated `https://…/live/index.m3u8` URL in the admin.
- Or port-forward `8888` (and `1935` for the broadcaster) on your router, behind
  a reverse proxy with TLS.

**Scale note:** one server streams to viewers directly, so a very large remote
audience needs a CDN in front (Cloudflare) or a managed provider (Mux,
Cloudflare Stream, AWS IVS) — those also auto-record. For a typical guest list
this self-hosted setup is fine.

## 5. Keep the recording for guests

After the event, the file is in `streaming/recordings/live/`. To make it a
permanent recording on the site:
- Upload it via **/admin → Gallery** (or an event's **recording**), **or**
- Host the file and paste its URL into the event's **Recording link**.
