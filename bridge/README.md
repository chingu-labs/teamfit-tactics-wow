# Bounded desktop-to-WoW step bridge

This generator prepares the Teamfit Tactics addon plus a finite pool of
load-on-demand slots. Teamfit Tactics Desktop can replace the payload in every
unused slot with the latest measured KingSmith WalkingPad session total. The
addon consumes one slot every polling interval while WoW remains open.

This is an experimental, bounded bridge. It has not been verified in a real WoW
client or with physical treadmill hardware. It does not control the treadmill,
inject game input, estimate steps from belt speed, reload the UI, or award
fitness credit.

## Prepare for the exact client

In the target Classic client, run `/dump select(4, GetBuildInfo())`. Close WoW,
then replace `11509` below with the returned interface number:

```sh
python3 bridge/steps.py prepare --interface 11509 --slots 64 --interval 5
```

Copy `TeamfitTactics` and all `TeamfitTacticsSlotNNNN` folders from
`dist/steps-ingress/` into that client's `Interface/AddOns/` directory before
launching WoW. Do not mix generated pools or overwrite unrelated addons.

At five-second polling, 64 slots cover at most 5 minutes 20 seconds. A four-hour
test needs 2,880 slots prepared before launch. Slot exhaustion is shown in-game
and requires a fresh game launch with a fresh generated pool; loaded slots are
never treated as reusable disk reads.

The generated `TeamfitTactics/step-bridge-manifest.json` is the desktop writer's
contract. Each atomic payload update calls `TeamfitTactics.Receive` with schema
version 1, source `kingsmith-wilink`, slot, source-session ID, sequence,
observation time, availability, and measured cumulative session steps. The addon
accepts this call only during its synchronous load of the expected slot.
This timing and schema check prevents accidental out-of-band updates; it is not
authentication against other installed addons, which share WoW's Lua runtime.

The panel shows the count only while a reading is fresh and available. It fails
closed on source-session changes, backwards sequence/time/count, loaded slots,
clock errors, manual stop, staleness, and exhaustion. `/teamfit` shows the panel;
`/teamfit stop` ends further reads for the current game session.
