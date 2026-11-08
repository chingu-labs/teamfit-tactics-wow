# Teamfit Tactics WoW addon

- Repository name: `teamfit-tactics-wow`. User-facing name: **Teamfit Tactics**.
- This is a standalone Lua addon. Do not import the mobile or desktop application.
- Use Lua 5.1-compatible syntax and keep quest logic independent of WoW globals.
- Run `make check` and `make test` with Lua 5.1. `LUA` and `LUAC` can select local binaries.
- A live in-game counter is essential. Do not substitute manual entries, paste
  codes, after-session recaps, periodic UI reloads, or an OS overlay without the
  owner's explicit choice.
- The old manual prototype is retired under `legacy/`, outside the addon manifest.
  Preserve its SavedVariables without interpreting them as measured data.
- The transport spike uses synthetic sequence numbers, never step counts. It
  proves no sensor behavior or in-game compatibility without a real client test.
- Initial target: Classic, Windows/macOS, phone/watch source. Foreground phone
  success does not establish live watch or locked-phone delivery.
- No account connection, chat broadcast, gameplay automation,
  payments, advertisements, or telemetry is implemented or implied.
- Verify new WoW API usage and interface versions against current client sources.
  Static checks and test doubles do not establish in-game compatibility.
- Obtain authorization before pushing, publishing, installing into WoW, or
  changing shared-service configuration. Preserve unrelated work.
