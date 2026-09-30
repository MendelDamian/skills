# pstack-mirror

Claude Code plugin marketplace that mirrors [`pstack`](https://github.com/cursor/plugins/tree/main/pstack) from `cursor/plugins`. A daily GitHub Action re-syncs it.

## Install

```
/plugin marketplace add MendelDamian/pstack-mirror
/plugin install pstack@pstack-mirror
```

## Update

Auto-update is off by default for third-party marketplaces. Enable it in `/plugin` → Marketplaces → pstack-mirror, or update manually:

```
/plugin marketplace update pstack-mirror
/plugin update pstack@pstack-mirror
```

## Layout

- `pstack/`: upstream copy. Never edit by hand, because the next sync overwrites it.
- `overlay/`: files layered on top after each sync (e.g. `pstack/.claude-plugin/plugin.json`).
- `UPSTREAM_COMMIT`: the upstream SHA last synced.
- `scripts/sync.sh`, `scripts/validate.sh`: used by `.github/workflows/sync.yml`, and can be run locally.

## Manual fallback

```
git clone https://github.com/MendelDamian/pstack-mirror && cp -R pstack-mirror/pstack/skills/* ~/.claude/skills/
```
