# Teamfit Tactics WoW addon

- Repository name: `teamfit-tactics-wow`. User-facing name: **Teamfit Tactics**.
- This is a standalone Lua addon. Do not import the mobile or desktop application.
- Use Lua 5.1-compatible syntax and keep quest logic independent of WoW globals.
- Run `make check` and `make test` with Lua 5.1. `LUA` and `LUAC` can select local binaries.
- Progress in the prototype is manually entered. Never describe it as measured,
  synced, live, or Riot-validated. It grants no Teamfit leaderboard credit.
- Preserve per-character saved quests across reloads. Keep history bounded.
- No network bridge, account connection, chat broadcast, gameplay automation,
  payments, advertisements, or telemetry is implemented or implied.
- Verify new WoW API usage and interface versions against current client sources.
  Static checks and test doubles do not establish in-game compatibility.
- Obtain authorization before pushing, publishing, installing into WoW, or
  changing shared-service configuration. Preserve unrelated work.
