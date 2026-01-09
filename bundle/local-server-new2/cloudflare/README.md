# Cloudflare Tunnel (quick notes)

This bundle runs the app locally on `http://127.0.0.1:5000`.
Use Cloudflare Tunnel to expose it externally without port forwarding.

Typical commands on the server machine:

1) Install cloudflared (one-time)
   - winget install Cloudflare.cloudflared

2) Login
   - cloudflared tunnel login

3) Create tunnel
   - cloudflared tunnel create keycabinet

4) Route DNS (requires your domain in Cloudflare)
   - cloudflared tunnel route dns keycabinet keys.yourdomain.no

5) Configure
   - Copy `config.yml.example` to `%USERPROFILE%\.cloudflared\config.yml` and fill placeholders.

6) Run
   - cloudflared tunnel run keycabinet

Lock down access in Cloudflare Zero Trust (Access policy) before using in production.
