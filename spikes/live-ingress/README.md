# Classic live-ingress diagnostic

This is a bounded transport test, **not a step counter**. It publishes synthetic
sequence numbers and timestamps to pre-created load-on-demand addons. Windows
and macOS use the same Python publisher and Lua source; neither platform has
been verified inside WoW here. No phone/watch, account or health data is used.

## Setup for the actual client

1. In the intended Classic client, record its exact flavor/build and interface
   number. The fourth return of `GetBuildInfo()` gives the interface version;
   `/dump select(4, GetBuildInfo())` can display it. Classic variants have
   different versions, so do not assume the example below matches your client.
2. Close WoW. From the repo, generate a new output directory. Replace `11509`
   with the interface number you just recorded:

   ```sh
   python3 spikes/live-ingress/probe.py prepare --interface 11509 --slots 64 --interval 5
   ```

   Use `python` on Windows if that is your Python 3 command. Preparation writes
   only a new output directory under `dist/`. It refuses to overwrite an
   existing directory and does not locate or install into WoW.
3. Manually copy the generated `TeamfitLiveProbe` and all
   `TeamfitLiveProbeSlotNNNN` folders from `dist/live-ingress-probe/` into the
   **test client's** `Interface/AddOns/` folder. These names are separate from
   the product addon. Do not replace or delete unrelated addon files.
4. Fully launch WoW after copying the folders, enable the main probe and its
   slots, then log in. The transport-test panel appears and polls automatically.
5. While the game remains open, run the publisher against the installed probe
   folder, keeping the matching slot folders in the same AddOns directory:

   ```sh
   python3 spikes/live-ingress/probe.py publish --addon "/path/to/Interface/AddOns/TeamfitLiveProbe" --ticks 12
   ```

   Windows example:

   ```powershell
   python spikes/live-ingress/probe.py publish --addon "C:\Games\World of Warcraft\_classic_era_\Interface\AddOns\TeamfitLiveProbe" --ticks 12
   ```

   This command replaces **only the diagnostic slot payloads**. Each publication
   prints how many files were written and how long writing took. The publisher
   exits after 12 publications by default. Ctrl+C also stops it.
6. Observe fixture sequences arriving without `/reload`, relogging or copying
   another payload. `/teamfitprobe` shows status; `/teamfitprobe stop` cancels
   further reads. Let a small pool exhaust and verify the panel says
   **EXHAUSTED**, rather than leaving a frozen value labeled live.

Readiness is deliberately polled with addon loading only. No sound-file flags,
screen capture, memory access, input generation, hidden reload or network call
is included. No runtime test is performed just by running the local test suite.

## What this can establish

- Whether unused, pre-created slots load the latest replaced file on this build.
- Whether automatic loading works during ordinary play, including combat.
- How failures and already-loaded slots behave, and how quickly staleness shows.
- Whether publisher restarts and duplicate sequences fail visibly.
- Actual file-write cost, client startup impact, memory growth and frame-time
  impact at the pool size under test. These must be measured on the real client.

The Python/Lua tests establish only our serializer and state-machine behavior.
They do not establish any of the above runtime properties.

## Sustained-session gate

Start small. At five-second polling, the default 64 slots last at most
5 minutes 20 seconds, including failed/empty loads. Slots are never recycled.
After the short diagnostic succeeds, generate a **separate** 2,880-slot test
for four hours at that cadence. Install before launching the client. The
publisher needs `--ticks 2880` for that test. Both schedules have startup and
polling phase effects; matching these counts alone does not prove four hours
of fresh delivery. Measure actual elapsed coverage and latency.

Do not claim a production bridge until both target platforms pass a sustained
real-client test with acceptable frame times and bounded memory. A very large
addon pool may be an unacceptable product even if it loads successfully.
Fresh file visibility and the failure of slot reuse must be observed on the
client; the code deliberately never treats `ResetAddOns` as a recycling API.

## Next gate: real movement

Only after ingress is viable, connect real phone readings. Measure sensor
batching and transport delay separately. A foreground phone proof does not
establish locked-phone or live watch delivery. Use source identity, sequence,
observation age and explicit stale/unavailable states; heartbeats must not make
old sensor readings look fresh. No interpolation or character-movement steps.

Acceptance for the eventual product requires sustained real walking/rest
intervals without reloads or manual transfers; disconnect/reconnect and source
resets without duplicate or catch-up steps; and stop/sign-out/account changes
that prevent delayed data from repopulating another session. An OS overlay is
a different surface and is not a fallback accepted by the owner.

## Evidence

The mechanism is inspired by the author's explanation in
[wow-ai's architecture](https://github.com/chelinho139/wow-ai/blob/main/docs/ARCHITECTURE.md),
which describes a finite 200-slot pool tested on Forever. That is not Classic
Era/progression compatibility evidence. Our implementation is original and
intentionally omits that project's agent integration and media signaling.

The [generated client API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)
exposes `C_AddOns.LoadAddOn`; actual disk/cache behavior still requires runtime
proof. No Blizzard endorsement or enforcement conclusion is implied.
