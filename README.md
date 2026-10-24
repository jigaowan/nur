# nur-packages

**My personal [NUR](https://github.com/jigaowan/nur) repository**

![Build and populate cache](https://github.com/jigaowan/nur/workflows/Build%20and%20populate%20cache/badge.svg)

[![Cachix Cache](https://img.shields.io/badge/cachix-tsunur-blue.svg)](https://tsunur.cachix.org)

Darwin service modules include [Caddy](darwin/caddy/README.md), available through
`darwinModules.caddy` or the `darwinModules.default` aggregate.

`cloudflare-cf` packages Cloudflare's agent-oriented CLI and provides both `cf`
and `cloudflare`. It supports x86_64 and aarch64 on Linux and Darwin, using
Node.js 22 from the consuming nixpkgs (22.23.0 or newer is required).

The version and npm release tarball are tracked by `nvfetcher.toml` against the
npm `latest` channel, which currently includes beta releases. After running
nvfetcher, refresh the runtime dependency lock with:

```sh
nix shell -f '<nixpkgs>' nodejs_22 python3 -c python3 pkgs/cloudflare-cf/update.py
```

The metadata update workflow runs both steps. The dependency updater does nothing
when the release version has not changed; Nix checks that the source and
lock file versions agree. `importNpmLock` fetches dependencies using the integrity
hashes in the lock file, so no separate dependency hash needs to be maintained.
