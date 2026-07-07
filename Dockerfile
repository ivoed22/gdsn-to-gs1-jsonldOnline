# Deployment-only image for ivoed22/gdsn-to-gs1-jsonld.
#
# This repo never vendors the app's source or reference data -- it clones
# the app repo at build time, pinned by APP_GIT_REF, so there is exactly
# one source of truth for the application. Rebuild with a different
# --build-arg APP_GIT_REF=<tag-or-commit> to move to a newer version.
#
# python:3.11-slim is an official multi-arch image (amd64 + arm64), so
# this also builds on Oracle Cloud's Always Free ARM (Ampere A1) instances.
FROM python:3.11-slim

ARG APP_GIT_REF=main
ARG APP_REPO_URL=https://github.com/ivoed22/gdsn-to-gs1-jsonld.git

# git: to clone the app repo.
# libxml2-dev/libxslt1-dev/build-essential: lxml is a C extension and
# needs these headers to build if a matching manylinux wheel isn't
# available for the target platform (notably on arm64).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       libxml2-dev \
       libxslt1-dev \
       build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/app

# Not a shallow `--branch` clone: the build-and-publish.yml workflow
# passes a full commit SHA (not a branch/tag name) for reproducibility,
# and `git clone --branch` only accepts refs that exist by that name on
# the remote -- it rejects arbitrary SHAs with exit code 128. A full
# clone + checkout works for a branch, a tag, or a raw SHA alike.
RUN git clone "${APP_REPO_URL}" . \
    && git checkout "${APP_GIT_REF}"

# The `app` extra in pyproject.toml pulls in streamlit; every other
# dependency (lxml, pydantic, pandas, pyld, jsonschema, qrcode, ...) is
# already a main dependency, so nothing extra is needed here.
RUN pip install --no-cache-dir -e ".[app]"

EXPOSE 8501

# Only reachable from inside the Docker network in docker-compose.yml --
# the cloudflared service is the sole public entry point.
CMD ["streamlit", "run", "app/streamlit_app.py", \
     "--server.address=0.0.0.0", \
     "--server.port=8501", \
     "--server.headless=true"]
