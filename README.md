# Teamfit Tactics for WoW

Turn tonight's leveling session into a walking challenge.

A free, MIT-licensed addon by Chingu Labs, developed at
[chingu-labs/teamfit-tactics-wow](https://github.com/chingu-labs/teamfit-tactics-wow).

**Status: early prototype.** Step progress is manually entered, and the addon
has not been tested inside WoW. Publishing the source does not establish
in-game compatibility or a supported addon release.

## First prototype

- Set a personal walking quest, such as 2,000 real-world steps.
- Enter the steps you took during that quest from your own step counter.
- See a small, draggable goal tracker and a goal-reached message.
- Finish to save a recap; retain the latest 20 recaps and lifetime local totals.
- Resume unfinished quests after a UI reload or login on the same character.

**Every step total is manually entered.** The addon does not measure steps,
read a watch, connect to Teamfit accounts, award leaderboard credit, or verify
that you were walking or playing. Enter the steps taken during the quest, not
your whole-day total. Updating a total replaces the previous entry; it does not
add to it. Starting a quest does not reset your physical step counter.

No combat-log access, chat broadcasts, polling, external libraries, telemetry,
custom artwork, or gameplay automation is included. All state stays in WoW's
per-character SavedVariables. An unfinished quest stays open until you finish
it; its timestamps do not establish playtime.

## Install locally

The initial manifest targets Retail interface versions `120105` and `120107`,
based on current addon manifests. **The addon has not been tested inside WoW.**
Classic support and additional client versions need separate in-game checks.

1. Clone this repository and run `make package` to build the installation ZIP.
2. Extract `TeamfitTactics` into your WoW installation's
   `_retail_/Interface/AddOns/` directory.
3. Restart WoW if this is a new addon folder, enable **Teamfit Tactics**, and
   enter `/teamfit`.

The installed layout must be `AddOns/TeamfitTactics/TeamfitTactics.toc`, not
an extra nested repository directory. Installing the addon is a manual step;
the build does not locate or modify a WoW installation.

## Commands

| Command | Action |
| --- | --- |
| `/teamfit` | Show or hide the tracker |
| `/teamfit start 2000` | Start a quest with a 2,000-step goal |
| `/teamfit steps 650` | Replace the current quest's manually entered total |
| `/teamfit finish` | Save a recap and finish the current quest |
| `/teamfit history` | Print the latest five recaps |
| `/teamfit resetposition` | Return the tracker to the center of the screen |
| `/teamfit help` | List commands |

Use the tracker buttons for the same start, update, and finish actions. Goals
must be whole numbers from 1 to 1,000,000; step totals may also be zero.

## Development

Requires Lua 5.1, its `luac` compiler, Make, and Python 3 (packaging only).
No package installation or global configuration is performed by these targets.

```sh
make check
make test
make package
```

Override `LUA=...` and `LUAC=...` for binaries outside `PATH`. Tests cover the
quest lifecycle, correction of totals, persistence, and bounded history. UI
smoke tests exercise registration and button actions through WoW API doubles;
they do not render the interface or emulate Blizzard's runtime.

Before a supported addon release, check on a real Retail client: installation, readable
layout, keyboard input, dragging and offscreen clamping, goal completion,
close/reopen, `/reload`, logout/login, character isolation, and operation during
combat without errors. No release acceptance or visual verification is claimed.

## Connection roadmap

First validate whether players enjoy setting and completing walking quests.
Then prototype an explicit session-summary import from the Teamfit phone app,
followed by a desktop-assisted bridge if that improves the experience.
Neither connection exists in this prototype. A conventional file-based bridge
may need a UI reload, so continuous live updates are not promised.

Keep imported sensor data distinct from manual entries and enforce any
competitive credit in Teamfit's backend. The addon remains free and useful
without an account. Do not add promotional popups or subscription gates.

## References

- [Blizzard's addon policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
- [Current DBM interface manifest](https://github.com/DeadlyBossMods/DeadlyBossMods/blob/master/DBM-Core/DBM-Core.toc)
- [Client Frame API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
- [TSM's documented reload requirement for updated external data](https://support.tradeskillmaster.com/en_US/addon/why-does-my-addon-keep-telling-me-no-recent-auctiondb-scan-data-found)

## License

[MIT](LICENSE). No Blizzard artwork, trademarks, or third-party addon code is
licensed by this repository. This is an independent community project.

