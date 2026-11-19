# syntax=docker/dockerfile:1
# Slim standalone Graphiti MCP Server image.
# OpenAI embeddings/LLM by default; connects to an external FalkorDB (or Neo4j).
#
# Size notes vs upstream docker/Dockerfile.standalone (~3.2GB):
# - No `providers` extra: drops sentence-transformers -> PyTorch/CUDA (~2.5GB).
# - No `azure` extra.
# - Multi-stage: pip/uv never ship in the final image; no curl/sfw either.

ARG PYTHON_VERSION=3.11
ARG GRAPHITI_CORE_VERSION=

FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

ARG GRAPHITI_CORE_VERSION=

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

WORKDIR /app/mcp

# Dependency manifests first so this layer stays cached.
COPY pyproject.toml ./

# Drop the local-path source override for graphiti-core, optionally pin it to
# the requested version, resolve a fresh lock, and install default deps only.
RUN set -eu; \
    sed -i '/\[tool\.uv\.sources\]/,/graphiti-core/d' pyproject.toml; \
    if [ -n "${GRAPHITI_CORE_VERSION}" ]; then \
      sed -i "s/graphiti-core\[falkordb\][>=]\+[0-9]\+\.[0-9]\+\.[0-9]\+/graphiti-core[falkordb]==${GRAPHITI_CORE_VERSION}/" pyproject.toml; \
    fi; \
    rm -f uv.lock; \
    uv lock; \
    uv sync --no-group dev --no-install-project

FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime

ENV PYTHONUNBUFFERED=1 \
    SERVER__HOST="0.0.0.0" \
    PATH="/app/mcp/.venv/bin:${PATH}"

WORKDIR /app/mcp

COPY --from=builder /app/mcp/.venv ./.venv
COPY main.py ./
COPY src/ ./src/
COPY config/ ./config/

ARG GRAPHITI_CORE_VERSION=
ARG MCP_SERVER_VERSION=1.1.3
ARG BUILD_DATE
ARG VCS_REF
RUN if [ -n "${GRAPHITI_CORE_VERSION}" ]; then \
      echo "${GRAPHITI_CORE_VERSION}" > .graphiti-core-version; \
    fi
LABEL org.opencontainers.image.title="Graphiti MCP Server (slim)" \
      org.opencontainers.image.description="Slim standalone Graphiti MCP server for an external FalkorDB/Neo4j" \
      org.opencontainers.image.version="${MCP_SERVER_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Custom" \
      org.opencontainers.image.source="https://github.com/getzep/graphiti" \
      graphiti.core.version="${GRAPHITI_CORE_VERSION}"

RUN mkdir -p /var/log/graphiti

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=4)" || exit 1

CMD ["python", "main.py"]
