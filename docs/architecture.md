# Architecture

This repo is **deployment-only**. It does not contain, mirror, or vendor
any application code or data from the app repo — there is exactly one
source of truth for that: [`ivoed22/gdsn-to-gs1-jsonld`](https://github.com/ivoed22/gdsn-to-gs1-jsonld).

```
                         ┌─────────────────────────────────┐
                         │   ivoed22/gdsn-to-gs1-jsonld     │
                         │   (source of truth: app code +   │
                         │    ~30MB reference data, its own │
                         │    versioned CI/CD, unaffected   │
                         │    by anything in this repo)     │
                         └────────────────┬──────────────────┘
                                          │ git clone (pinned APP_GIT_REF)
                                          │ at Docker build time
                                          ▼
┌───────────────────────────────────────────────────────────────────┐
│  Always-on host (e.g. Oracle Cloud Always Free ARM instance,       │
│  or any machine you keep running: your own PC/NAS also works)      │
│                                                                     │
│   docker compose                                                   │
│   ┌───────────────┐   internal network only   ┌─────────────────┐  │
│   │  app (Docker) │ ◄───────────────────────── │  cloudflared     │  │
│   │  Streamlit,    │        http://app:8501     │  (Cloudflare     │  │
│   │  port 8501     │                            │   Tunnel client) │  │
│   └───────────────┘                            └────────┬─────────┘  │
└──────────────────────────────────────────────────────────┼──────────┘
                                                            │ outbound-only
                                                            │ connection
                                                            ▼
                                            ┌───────────────────────────┐
                                            │   Cloudflare network       │
                                            │   (TLS, DDoS protection,   │
                                            │    your public domain)     │
                                            └───────────────┬───────────┘
                                                            │
                                                            ▼
                                                      public visitors
```

Why this split:

- **One source of truth.** The app repo keeps its own CI-gated,
  one-commit-per-version release discipline completely untouched.
  Nothing here duplicates its code or its committed reference data
  (WebVoc snapshot, GDSN codelists, mapping catalog) — the Dockerfile
  clones it fresh at build time.
- **No inbound ports opened on the host.** `cloudflared` makes an
  outbound-only connection to Cloudflare; there is no port-forwarding
  or firewall rule needed on the VM. `app` is not published to the
  host at all — only `cloudflared` can reach it, over the Docker
  Compose internal network.
- **Zero app code changes.** The Streamlit app runs exactly as it does
  today; nothing in `ivoed22/gdsn-to-gs1-jsonld` needs to know it is
  being tunneled.

See [`README.md`](../README.md) for the full setup walkthrough.
