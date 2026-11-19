# Graphiti MCP Server (slim image) — fork of upstream

> **This repo is a fork** of the upstream
> [Graphiti MCP server](https://github.com/getzep/graphiti/tree/main/mcp_server)
> (`getzep/graphiti`, app code in `main.py` / `src/` / `config/`, unchanged except where noted
> in `pyproject.toml`). All credit for the server itself goes to the Zep AI / Graphiti team;
> this fork only re-packages it into a slim Docker image.

A slim Docker packaging of the upstream Graphiti MCP server.

Compared with the upstream `docker/Dockerfile.standalone` (~3.2GB), this image:

- installs only the default dependencies — **no `providers` / `azure` extras**, so no
  sentence-transformers → PyTorch/CUDA (~2.5GB saved)
- uses a **multi-stage build** (no pip/uv/curl/sfw in the final image)
- ships a python-based healthcheck instead of curl

Expected size: **~350MB**.

## Configuration

LLM + embeddings default to OpenAI (set `OPENAI_API_KEY`). Point `api_base` at an
OpenAI-compatible endpoint (Ollama, vLLM, …) for local models. The server connects to an
**external FalkorDB** (default) or Neo4j — configure via `config/config.yaml`, env vars, or CLI
flags (same precedence as upstream). See the upstream
[README](https://github.com/getzep/graphiti/tree/main/mcp_server#configuration) for details.

## Build locally

```sh
docker build -t graphiti-mcp .
# optionally pin graphiti-core:
docker build --build-arg GRAPHITI_CORE_VERSION=0.31.1 -t graphiti-mcp .
```

## Run

```sh
docker run --rm -p 8000:8000 --env-file .env graphiti-mcp
```

- MCP endpoint: `http://localhost:8000/mcp` (also available with a trailing slash — it redirects)
- Health check: `http://localhost:8000/health`

## CI

`.github/workflows/docker.yml` builds on pushes to `main`, tags, and PRs (build-only),
fetches the latest `graphiti-core` version from PyPI, pins it as a build arg, and pushes
multi-platform images (amd64 + arm64) to `ghcr.io/<owner>/<repo>` with tags
`latest`, the git SHA, `core-<version>`, and `v*` tags.

Repo settings needed: **Settings → Actions → General → Workflow permissions → Read and
write permissions** (for `GITHUB_TOKEN` to push to GHCR).
