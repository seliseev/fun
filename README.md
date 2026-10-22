# FUN

In-house framework for Defold games: module lifecycle, save, wallet/tokens, gamedata,
targets, localization, ads, IAP, no-ads, analytics, MMP, sound, rate us, segmentation,
Yandex Games integration.

## Installation

Add the library to `game.project` → `[project] dependencies`:

```
https://github.com/seliseev/fun/archive/refs/tags/<version>.zip
```

The repository is private, so use basic auth with credentials from environment variables
(see [Defold libraries](https://defold.com/manuals/libraries/#basic-access-authentication)):

```
https://__FUN_GITHUB_USER__:__FUN_GITHUB_TOKEN__@github.com/seliseev/fun/archive/refs/tags/<version>.zip
```

### Required dependencies

Defold dependencies are not transitive — the host project must provide:

| Require path | Library |
|---|---|
| `event.*` | [Insality/defold-event](https://github.com/Insality/defold-event) 21 |
| `saver.*` | [Insality/defold-saver](https://github.com/Insality/defold-saver) 5 |
| `tweener.*` | [Insality/defold-tweener](https://github.com/Insality/defold-tweener) 6 |
| `token.*` | [Insality/defold-token](https://github.com/Insality/defold-token) 9 |
| `druid.*` | [Insality/druid](https://github.com/Insality/druid) 1.x |
| `monarch.*` | [britzl/monarch](https://github.com/britzl/monarch) |
| `stately.*` | [britzl/stately](https://github.com/britzl/stately) |
| `yagames.*` | [indiesoftby/defold-yagames](https://github.com/indiesoftby/defold-yagames) 0.19.0 (mock on non-HTML5) |

Store SDKs (admob, iap, firebase, facebook, gameanalytics, tenjin …) are needed only for
the providers selected by the target.

## Usage

- Add `/fun/fun.collection` (via a collection proxy or directly) to the bootstrap collection.
- Register game modules with `fun.register_module(name, module)` before init, wait for
  `fun.on_fun_inited`.
- Work with currencies through `fun.modules.wallet` (container `wallet` of defold-token). Subscribe to
  `wallet.on_change(token_id, amount, delta, reason_category, reason_id)` instead of `token.on_token_change`:
  wallet passes `reason_category`/`reason_id` to defold-token as one `reason` table.
- Settings (`fun/ext.properties`, section `[fun]`): `target`, `gamedata_path`,
  `monarch_data_path`, `targets_data_path`. Defaults point to `/assets/*.json` in the host project.

## Example

The repository is a runnable Defold project, like [druid](https://github.com/Insality/druid):
open `game.project` in the Defold editor and run it. Only `/fun` is exported as a library
(`[library] include_dirs`), `/example` stays in this repo.

`/example` is a minimal game built on FUN:

- `loader.collection` — bootstrap: splash → loading, loads `fun.collection` and `game.collection` via proxies,
  registers game modules (`level_manager`, `cohorts`, `iconfinder`) before `fun.init()`.
- `game.collection` — monarch screens (HUD, level, win, bank, settings, language, level chest, no ads,
  rate us, popups, cheats) and controllers (ads, iap, analytics, sound, save triggers, rate us).
- `modules/level_manager.lua` — stub of a game core: the level is completed with the "WIN" button,
  `LEVEL_WIN` drives the level chest, win rewards, interstitials and cohorts.
- `assets/` — `gamedata.json`, `targets.json` (target `development` uses dummy ads and IAP providers,
  other targets contain placeholders only), `monarch.json`, localization.

