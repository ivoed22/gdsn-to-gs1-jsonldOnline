# gdsn-to-gs1-jsonldOnline

Deployment for a free, always-on, Cloudflare-fronted public instance of
[`gdsn-to-gs1-jsonld`](https://github.com/ivoed22/gdsn-to-gs1-jsonld) —
the GS1-first Digital Product Passport / GDSN standards workbench.

This repo contains **only deployment artifacts** (Dockerfile, Compose
file, this guide) — no application code. See
[`docs/architecture.md`](docs/architecture.md) for why, and a diagram.

**No code changes to the app itself.** The Streamlit app runs exactly
as it does in its own repo; this repo just runs it in a container and
puts a Cloudflare Tunnel in front of it.

## What you need before starting

- A Cloudflare account with a domain added to it (any domain you
  control — a subdomain like `dpp.yourdomain.com` works fine).
- A place to run Docker, always on, for free. Two good options:
  - **Oracle Cloud Always Free tier** — a real ARM (Ampere A1) VM,
    free forever (not a trial), genuinely always-on (not a
    serverless function that sleeps). Availability/region capacity
    can vary at signup; if your first choice of region is full, try
    another Always Free–eligible region.
  - **Any machine you already keep running** — your own PC, a NAS, a
    Raspberry Pi. Works identically; "always on" then depends on that
    machine staying on.
- ~15–20 minutes for the one-time setup below.

## Step 1 — Create the Cloudflare Tunnel

1. Log in to the Cloudflare dashboard → **Zero Trust** → **Networks** →
   **Tunnels**.
2. **Create a tunnel** → choose the **Docker** connector.
3. Copy the token shown (a long string). This is your
   `CLOUDFLARE_TUNNEL_TOKEN` — you'll paste it into `.env` in Step 4.
   Don't close this page yet.
4. Still on the tunnel's configuration page, go to **Public Hostname**
   → **Add a public hostname**:
   - **Subdomain**: whatever you want (e.g. `dpp`).
   - **Domain**: your domain.
   - **Service Type**: `HTTP`.
   - **URL**: `app:8501` (the Docker Compose service name and port —
     *not* `localhost`, since the request originates inside the
     `cloudflared` container on the compose network).
   - Save.

This is the only step where Cloudflare needs manual configuration;
everything else is `docker compose up`.

## Step 2 — Provision the always-on host

If using Oracle Cloud Always Free:

1. Sign up at [cloud.oracle.com](https://cloud.oracle.com) (free tier;
   a card is required for identity verification but the Always Free
   resources are not billed).
2. Create a Compute instance: shape **VM.Standard.A1.Flex** (Ampere
   ARM, Always Free eligible — check current free-tier limits in the
   console, they're generous for this workload), Ubuntu or
   Oracle Linux image, add your SSH key.
3. In the instance's **Virtual Cloud Network** security list, no
   inbound rule is needed for the app itself (see architecture note
   above) — only your own SSH access (port 22) needs to stay open.
4. SSH in once it's running.

If using your own machine instead, just make sure Docker is installed
and SSH/local access works — skip straight to Step 3.

## Step 3 — Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# log out and back in for the group change to take effect
```

(Docker's official install script supports both amd64 and arm64.)

## Step 4 — Clone this repo and configure

```bash
git clone https://github.com/ivoed22/gdsn-to-gs1-jsonldOnline.git
cd gdsn-to-gs1-jsonldOnline
cp .env.example .env
nano .env   # paste your CLOUDFLARE_TUNNEL_TOKEN from Step 1
```

## Step 5 — Start it

```bash
docker compose up -d --build
docker compose logs -f    # watch both containers come up; Ctrl+C to stop watching (they keep running)
```

`app` needs to report healthy before `cloudflared` starts (see the
healthcheck in `docker-compose.yml`) — the first build can take a few
minutes (installing `pandas`/`lxml` etc. from source on ARM if no
prebuilt wheel is available for that platform/Python version).

## Step 6 — Verify

Visit `https://dpp.yourdomain.com` (whatever hostname you chose in
Step 1). You should see the workbench landing page.

## Updating to a newer version of the app

```bash
cd gdsn-to-gs1-jsonldOnline
git pull                                   # picks up any changes to this deploy repo itself
docker compose build --pull --build-arg APP_GIT_REF=main   # or a specific tag/commit
docker compose up -d
```

## Troubleshooting

- **`docker compose logs app`** — Streamlit boot errors, missing
  reference data, Python exceptions.
- **`docker compose logs cloudflared`** — tunnel connection status;
  "Registered tunnel connection" means it's connected to Cloudflare.
- **502 / "no healthy origin" from Cloudflare** — the Public Hostname
  URL in Step 1 must be `app:8501`, not `localhost:8501` — from inside
  the `cloudflared` container, `app` is the only way to reach the app
  container.
- **`lxml`/`pandas` build errors on ARM** — these packages publish
  `manylinux`/`musllinux` **aarch64** wheels for recent Python versions,
  so a source build usually only happens if pip can't find a matching
  wheel for the exact Python/OS combination. If it happens, the build
  will still succeed (this Dockerfile installs the headers/toolchain
  needed to compile from source) — it will just take longer.
- **Container restarts in a loop** — check `docker compose logs app`
  first; a common cause is a missing/renamed file in the app repo at
  the pinned `APP_GIT_REF` (e.g. after a structural change upstream).

## Not included (yet)

- Automated CI/CD (e.g. auto-rebuild on every push to the app repo's
  `main`). For now, updates are a manual `docker compose build --pull`
  — intentional, to keep this first version simple and predictable.
- Any modification to the app itself — that always happens in
  [`ivoed22/gdsn-to-gs1-jsonld`](https://github.com/ivoed22/gdsn-to-gs1-jsonld).
