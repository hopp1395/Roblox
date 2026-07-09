# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"Road Rampage" — a small Roblox arcade driving game (Luau) synced into Roblox Studio via Rojo. There is no build step, package manager, linter, or test suite; the three source files under `src/` are the entire game. Documentation and in-game text (HUD, status messages) are in German.

## Running the project

There is no CLI build/test/lint command — this project is only run inside Roblox Studio via Rojo:

```powershell
winget install Rojo-rbx.Rojo   # one-time install
rojo plugin install            # one-time Studio plugin install
rojo serve                     # run from the repo root
```

Then open Roblox Studio, connect the Rojo plugin, sync, and press Play. To verify a change actually works, this is the only way — there is no headless test harness.

`default.project.json` maps `src/` folders into Roblox services:
- `src/ReplicatedStorage/Shared` → `ReplicatedStorage.Shared`
- `src/ServerScriptService` → `ServerScriptService`
- `src/StarterPlayer/StarterPlayerScripts` → `StarterPlayer.StarterPlayerScripts`

## Architecture

Three scripts, strict client/server split typical of Roblox:

- **`src/ReplicatedStorage/Shared/GameConfig.lua`** — a single table of all tunable constants (road/traffic/bonus geometry, speed/accel/steer physics, sound asset ids). Required by both server and client. When balancing gameplay, change values here rather than hardcoding numbers elsewhere.
- **`src/ServerScriptService/RoadRampage.server.lua`** — authoritative game logic. On startup it tears down and rebuilds `ReplicatedStorage.RoadRampageRemotes` (a `RemoteEvent` called `InputChanged`) and `workspace.RoadRampageWorld` (containing `Lanes` and `Cars` folders). Runs entirely off a single `RunService.Heartbeat` loop that advances every player's `state` (position, speed, score, crash/finish flags) each frame.
- **`src/StarterPlayer/StarterPlayerScripts/CarController.client.lua`** — captures WASD/arrow input, fires `InputChanged` to the server (only when throttle/steer values change), and drives the camera + HUD off the local player's car every `RenderStepped`.

### Key patterns

- **Per-player lanes**: each player gets their own isolated parallel track ("lane"), offset along X by `GameConfig.LANE_SPACING`. Players don't share a road or interact with each other — this is really N single-player tracks running side by side. Lanes, traffic, and bonuses are created lazily and cached in `lanes[laneIndex]`.
- **Streaming world generation**: road segments, oncoming traffic, and bonus items are generated ahead of the car (`ensureRoadAhead`, `ensureTrafficAhead`, `ensureBonusAhead`, all keyed off `ROAD_LOOKAHEAD`/`SPAWN_LOOKAHEAD`) and culled behind it (`SPAWN_CULL_DISTANCE`) inside `updatePlayerState`, which runs once per player per Heartbeat tick.
- **Oncoming traffic movement**: unlike the old static obstacles, traffic vehicles (`lane.traffic`, created by `createTrafficVehicle`) each carry their own `speed` (randomized between `TRAFFIC_SPEED_MIN`/`TRAFFIC_SPEED_MAX`) and drive toward the player (decreasing Z) independent of the player's own speed. `updatePlayerState` advances every vehicle's `z` by `vehicle.speed * dt` and repositions it via `positionTrafficVehicle` every tick, so the closing speed on collision is the sum of the player's and the vehicle's speed.
- **Server→client state sync via Attributes, not RemoteEvents**: the server writes `Speed`, `Score`, `GameState`, `StatusText`, `ElapsedTime` as Instance attributes on the car's `Body` part (see `crashPlayer`, `updatePlayerState`). The client never listens for a state RemoteEvent — `CarController` just polls `currentCarBody:GetAttribute(...)` every `RenderStepped` in `updateHud`. Client→server input, by contrast, does use a `RemoteEvent` (`InputChanged`).
- **Ownership discovery**: the client finds its own car by scanning `workspace.RoadRampageWorld.Cars` for a model/body whose `OwnerUserId` attribute matches `player.UserId` (`refreshCurrentCar`), re-run whenever `Cars` gains/loses a child.
- **Collision/scoring** happens in `updatePlayerState`: traffic vehicles that fall behind the car award a point and get destroyed; vehicles within `CAR_HALF_WIDTH`/`CAR_HALF_LENGTH` (scaled) of the car trigger `crashPlayer` and halt that player's state permanently. Bonus items work the same way but add variable points instead of crashing.
