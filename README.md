# Teamfit Tactics for WoW

A free, MIT-licensed addon by Chingu Labs:
[chingu-labs/teamfit-tactics-wow](https://github.com/chingu-labs/teamfit-tactics-wow).

**Product requirement: a live in-game counter of real-world steps.** Initial
proof targets WoW Classic on Windows and macOS, using a phone/watch source.
Manual entries, pasted summaries, after-session recaps, routine UI reloads and
an OS overlay do not satisfy that requirement.

## Current status

The manual-entry prototype is retired. Its code is kept under `legacy/`, outside
the addon manifest and installation package. Existing per-character saved data
is preserved without being interpreted as measured steps. `/teamfit` reports
that live tracking is not yet available; it collects no steps.

The next gate is [the isolated live-ingress diagnostic](spikes/live-ingress/README.md).
It tests whether the actual Classic client can automatically read fresh data
through previously unused load-on-demand addon slots. It uses synthetic sequence
numbers explicitly labeled as transport fixtures, never step counts.

**A live step counter has not been implemented or verified.** The diagnostic
is not a sensor bridge, a renewable transport, or evidence of Blizzard approval.
No client was installed or controlled, and no production service was changed.
Phone acquisition, any watch delivery, secure transport, source freshness and
account isolation still need their own end-to-end proof.

## Why test the bridge first?

Ordinary Lua files already loaded into WoW do not become live data merely
because a companion replaces them on disk. An author-documented alternative
loads a fresh addon from a pre-created pool for each update. That pool is finite:
200 slots at one read every five seconds lasts 16 minutes 40 seconds. A
four-hour session at that cadence needs at least 2,880 slots. Increasing the
pool is a hypothesis to measure, not a demonstrated product solution.

The diagnostic deliberately exposes stale, stopped and exhausted states. It
never reloads the UI, writes game memory, injects input, uses sound-file
signaling, connects to an account, or awards fitness credit.

## Development

Requires Lua 5.1 and its `luac` compiler, Make, and Python 3. No third-party
Python packages are needed. Override `LUA=...`, `LUAC=...` and `PYTHON=...` as
needed on the host.

```sh
make check
make test
make package
```

`make package` builds the current product shell, not a working live counter.
Generate the diagnostic separately for your exact client build using its
[setup instructions](spikes/live-ingress/README.md).

Tests cover preservation of legacy data, disabled manual commands, transport
freshness/replay/exhaustion states, fixture generation and the Python-to-Lua
payload contract. WoW API doubles do not render the interface or prove runtime
file loading, client compatibility, performance or real sensor behavior.

## References

- [Blizzard addon policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
- [Generated client addon API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)
- [Author-documented finite-slot bridge](https://github.com/chelinho139/wow-ai/blob/main/docs/ARCHITECTURE.md)
- [Current interface-version reference](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/master/DBM-Core/DBM-Core.toc)

## License

[MIT](LICENSE) for our original source. No Blizzard artwork, trademarks, or
third-party addon code is licensed by this repository. Independent community
project; not a supported addon release.
