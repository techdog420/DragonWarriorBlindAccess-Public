# Playtesting Notes

Updated: 2026-08-29

This file tracks the shift from map decoding toward actual blind-player gameplay.

## Latest Notes

- The second Kol return-corridor recovery batch is source-complete and
  live-verified (`2026-08-29`). Northern Cave, Mountain Cave, and Swamp Cave
  North now recognize the exact disconnected portions of the 373-cell
  `kol_return_staging` corridor through their existing northwestern-return
  variants. Before the patch, they had 155, 82, and 155 openings respectively
  over the connected 24-step bound. Destination-specific corridor bounds cover
  only those holes; the Swamp Cave bridge alias can now consider the western
  return when the shared west strip is nearer. Existing Mountain Cave-local and
  Swamp Cave Bridge-local selection regressions remain green. All 1,119
  combinations retain the selected target with no opening over 24 steps. From
  `(31,81)`, all three start `kol_return_staging` and target `Hauksness north
  ridge` at `(29,82)`, two steps west and one south. No waypoint geometry or
  movement timing changed. Focused route tests pass `335/335`; Lua syntax, all
  33 host-runnable Lua suites, all 68 Python tests, speech dependency, and
  command-queue checks pass. Loaded starts retained Swamp Cave North at frame
  `2083`, Northern Cave at frame `2618`, and Mountain Cave at frame `3315`;
  each selected the expected corridor and waypoint. Shift+R preserved the
  routes at frames `2290`, `2862`, and `3513`; Shift+U stopped them cleanly at
  frames `2501`, `3041`, and `3720`. Fresh frame `6660` found World Map
  `(31,81)` with path target nil, zero NPC/runtime blockers, and no new script
  error.
- The first Kol return-corridor recovery batch is source-complete and
  live-verified (`2026-08-29`). Brecconary, Erdrick's Cave, and Garinham now
  recognize the disconnected western portion of the 373-cell
  `kol_return_staging` corridor through their existing western-return variants.
  Before the patch, each destination had 140 openings over the connected
  24-step bound; Brecconary reproduced a rejected 71-step opening at `(31,81)`.
  Membership is limited to exact corridor cells with `y >= 30`, preserving the
  already-correct Garinham-local overlap farther north. All 1,119 combinations
  now retain the selected target with no opening over 24 steps. From `(31,81)`,
  all three start `kol_return_staging` and target `Hauksness north ridge` at
  `(29,82)`, two steps west and one south. No waypoint geometry or movement
  timing changed. Focused route tests pass `334/334`; Lua syntax, all 33
  host-runnable Lua suites, all 68 Python tests, speech dependency, and
  command-queue checks pass. Loaded starts retained Brecconary at frame `2079`,
  Erdrick's Cave at frame `2804`, and Garinham at frame `3594`; each selected
  the expected corridor and waypoint. Shift+R preserved the routes at frames
  `2345`, `3017`, and `3882`; Shift+U stopped them cleanly at frames `2602`,
  `3199`, and `4167`. Tagged readiness passed at frame `6720`, which found
  World Map `(31,81)` with path target nil, zero NPC/runtime blockers, and no
  new script error.
- The final Hauksness return-corridor source audit is complete and awaiting
  live validation (`2026-08-29`). Rimuldar was the only remaining selector
  hole: 75 of the 125 exact `hauksness_return_staging` cells opened beyond the
  connected 14-step bound. Magic Temple, Charlock, Tantegel, Hauksness,
  Cantlin, and Great Swamp were already connected through existing shared or
  local routes. Rimuldar now recognizes the Hauksness return through its
  existing staging chain, with no waypoint geometry or movement timing change.
  Dedicated tests now cover all 2,000 corridor/destination combinations—125
  cells across all 16 landmarks—with no opening over 14 steps. From `(73,96)`,
  Rimuldar, Magic Temple, and Charlock each start
  `hauksness_return_staging` and target `Cantlin north road` at `(73,91)`, five
  steps north. Focused route tests pass `333/333`; Lua syntax, all 33
  host-runnable Lua suites, all 68 Python tests, speech dependency, and
  command-queue checks pass. Reload `main.lua` and validate those three
  selections from clear World Map `(73,96)`, using Shift+U between selections.
- The third Hauksness return-corridor recovery batch is source-complete and
  live-verified (`2026-08-29`). Swamp Cave North, Swamp Cave South, and Rainbow
  Bridge now recognize all 125 exact cells on
  `hauksness_return_staging` through their existing cave and final-progression
  wrappers. Before the patch, each had 87 openings over the connected 24-step
  bound. At `(73,97)`, Swamp Cave North attempted 77 steps and exceeded the
  planner limit; Swamp Cave South and Rainbow Bridge each opened 41 steps
  through the wrong cave return. All 375 combinations now retain the selected
  destination with no opening over 14 steps. From `(73,96)`, all three start
  `hauksness_return_staging` and target `Cantlin north road` at `(73,91)`, five
  steps north. No waypoint geometry or movement timing changed. Focused route
  tests pass `331/331`; Lua syntax, all 33 host-runnable Lua suites, all 68
  Python tests, speech dependency, and command-queue checks pass. Loaded starts
  retained Swamp Cave North at frame `787`, Swamp Cave South at frame `1416`,
  and Rainbow Bridge at frame `2533`; each selected the expected corridor and
  waypoint. Shift+R preserved the routes at frames `986`, `1648`, and `2747`;
  Shift+U stopped them cleanly at frames `1149`, `1829`, and `2918`. Fresh
  frame `5220` found World Map `(73,96)` with path target nil, zero NPC/runtime
  blockers, and no new script error.
- The second Hauksness return-corridor recovery batch is source-complete and
  live-verified (`2026-08-29`). Kol, Northern Cave, and Mountain
  Cave now recognize all 125 exact cells on `hauksness_return_staging` through
  their existing northwestern-return variants. Before the patch, Kol had 59
  openings over the connected 24-step bound; Northern Cave and Mountain Cave
  each had 87. At `(73,97)`, Kol opened 53 steps while the two cave routes each
  attempted 77 steps and exceeded the planner limit. All 375 combinations now
  retain the selected destination with no opening over 14 steps. From
  `(73,96)`, all three start `hauksness_return_staging` and target `Cantlin
  north road` at `(73,91)`, five steps north. No waypoint geometry or movement
  timing changed. Focused route tests pass `330/330`; Lua syntax, all 33
  host-runnable Lua suites, all 68 Python tests, speech dependency, and
  command-queue checks pass. Loaded starts retained Kol at frame `2037`,
  Northern Cave at frame `2508`, and Mountain Cave at frame `3125`; each
  selected the expected corridor and waypoint. Shift+R preserved the active
  routes at frames `2222`, `2764`, and `3326`; Shift+U stopped them cleanly at
  frames `2286`, `2931`, and `3502`. Fresh frame `5520` found World Map
  `(73,96)` with path target nil, zero NPC/runtime blockers, and no new script
  error.
- The first Hauksness return-corridor recovery batch is source-complete and
  live-verified (`2026-08-29`). Brecconary, Erdrick's Cave, and
  Garinham now recognize all 125 exact cells on `hauksness_return_staging`
  through their existing western-return variants. Before the patch, each had
  87 openings over the connected 24-step bound. At `(73,97)`, their direct
  routes attempted 81, 82, and 82 steps and exceeded the planner limit. All
  375 combinations now retain the selected destination with no opening over 14
  steps. From `(73,96)`, each starts `hauksness_return_staging` and targets
  `Cantlin north road` at `(73,91)`, five steps north. No waypoint geometry or
  movement timing changed. Focused route tests pass `329/329`; Lua syntax, all
  33 host-runnable Lua suites, all 68 Python tests, speech dependency, and
  command-queue checks pass. Loaded starts retained Brecconary at frame `2471`,
  Erdrick's Cave at frame `3277`, and Garinham at frame `3776`; each selected
  the expected corridor and waypoint. Shift+R preserved the active routes at
  frames `2744`, `3478`, and `4000`; Shift+U stopped them cleanly at frames
  `2947`, `3647`, and `4158`. Fresh frame `7260` found World Map `(73,96)` with
  path target nil, zero NPC/runtime blockers, and no new script error.
- Final Charlock coverage on the Cantlin return corridor is source-complete and
  live-verified (`2026-08-28`). The accepted Rainbow Bridge
  corridor integration already connects Charlock through their shared
  `FINAL_PROGRESSION_STAGING` chain, so no redundant production selector was
  added. The new regression checks all 85 exact `cantlin_return_staging` cells,
  retains Charlock Castle as the requested final destination, and keeps every
  opening within 14 steps. At `(85,113)`, Charlock starts
  `cantlin_return_staging` toward `Great Swamp east lane` at `(89,113)`, four
  steps east. Focused route tests pass `328/328`; Lua syntax, all 33
  host-runnable Lua suites, all 68 Python tests, speech dependency, and
  command-queue checks pass. Loaded selection at frame `71879` retained
  Charlock, started `cantlin_return_staging`, and targeted `Great Swamp east
  lane`; Shift+R at frame `72140` reported the same route, waypoint, and index.
  Fresh frame `75600` found World Map `(85,113)` with path target nil, zero
  NPC/runtime blockers, and no new script error. All supported destinations on
  this 85-cell corridor are now source- and live-verified.
- The fourth Cantlin return-corridor recovery batch is source-complete and
  live-verified (`2026-08-28`). Rimuldar, Magic Temple, and Rainbow
  Bridge now recognize exact `cantlin_return_staging` corridor membership
  through their existing destination itineraries. The pre-patch audit found 80
  overlong openings for each destination, 240 total. At `(85,113)`, the
  openings were 18, 81, and 45 steps respectively. All 255 combinations now
  retain the requested destination with no opening over 14 steps. At
  `(85,113)`, each starts `cantlin_return_staging` and targets the nearest
  `Great Swamp east lane` waypoint at `(89,113)`, four steps east. Focused
  route tests pass `327/327`; Lua syntax, all 33 host-runnable Lua suites, all
  68 Python tests, speech dependency, and command-queue checks pass. Loaded
  starts retained Rimuldar at frame `790`, Rainbow Bridge at frame `1612`, and
  Magic Temple at frame `2689`; each selected the expected corridor and
  waypoint. Shift+R preserved the active routes at frames `1046`, `1882`, and
  `2941`; Shift+U stopped them cleanly at frames `1224`, `2082`, and `3147`.
  Fresh frame `5280` found World Map `(85,113)` with no active path, NPC
  blockers, runtime blockers, or new script error.
- The third Cantlin return-corridor recovery batch is source-complete and
  live-verified (`2026-08-28`). Hauksness, Swamp Cave North, and
  Swamp Cave South now recognize exact `cantlin_return_staging` corridor
  membership through their existing destination wrappers. The pre-patch audit
  found 27 overlong Hauksness openings and 80 each for the two cave
  destinations. At `(85,113)`, the openings were 81, 81, and 45 steps
  respectively. All 255 combinations now retain the requested destination with
  no opening over 14 steps. At `(85,113)`, each starts
  `cantlin_return_staging` and targets the nearest `Great Swamp east lane`
  waypoint at `(89,113)`, four steps east. Focused route tests pass `326/326`;
  Lua syntax, all 33 host-runnable Lua suites, all 68 Python tests, speech
  dependency, and command-queue checks pass. Loaded starts retained Hauksness
  at frame `795`, Swamp Cave North at frame `3296`, and Swamp Cave South at
  frame `4575`; each selected the expected corridor and waypoint. Shift+R
  preserved the active routes at frames `1078`, `3674`, and `4859`; Shift+U
  stopped them cleanly at frames `1258`, `3804`, and `5109`. Fresh frame `7440`
  found World Map `(85,113)` with no active path, NPC blockers, runtime
  blockers, or new script error.
- The second Cantlin return-corridor recovery batch is source-complete and
  live-verified (`2026-08-28`). Kol, Northern Cave, and Mountain
  Cave now recognize exact `cantlin_return_staging` corridor membership through
  their existing northwestern-return variants. Before the patch, the permanent
  regression reproduced an 81-step Kol opening. All 255 combinations now
  retain the requested destination with no opening over 14 steps. At
  `(85,113)`, each starts `cantlin_return_staging` and targets the nearest
  `Great Swamp east lane` waypoint at `(89,113)`, four steps east. Focused
  route tests pass `325/325`; Lua syntax, all 33 host-runnable Lua suites, all
  68 Python tests, speech dependency, and command-queue checks pass. Loaded
  starts retained Kol at frame `2710`, Mountain Cave at frame `3979`, and
  Northern Cave at frame `4674`; each selected the expected corridor and
  waypoint. Shift+R preserved the active routes at frames `3010`, `4276`, and
  `4993`; Shift+U stopped them cleanly at frames `3182`, `4465`, and `5173`.
  Fresh frame `8040` found World Map `(85,113)` with no active path, NPC
  blockers, runtime blockers, or new script error.
- The first Cantlin return-corridor recovery batch is source-complete and
  live-verified (`2026-08-28`). Brecconary, Erdrick's Cave, and
  Garinham now recognize exact `cantlin_return_staging` corridor membership
  through their existing western-return variants. Before the patch, each had
  80 openings over the connected 24-step bound, 240 total; Brecconary from
  `(85,113)` attempted a 109-step synthetic opening. All 255 combinations now
  retain the requested destination with no opening over 14 steps. At
  `(85,113)`, each starts `cantlin_return_staging` and targets the nearest
  `Great Swamp east lane` waypoint at `(89,113)`, four steps east. Focused
  route tests pass `324/324`; Lua syntax, all 33 host-runnable Lua suites, all
  68 Python tests, speech dependency, and command-queue checks pass. Loaded
  starts retained Brecconary at frame `1864`, Erdrick's Cave at frame `4034`,
  and Garinham at frame `4465`; each selected the expected corridor and
  waypoint. Shift+U stopped them cleanly at frames `3976`, `4292`, and `4769`.
  Fresh frame `18900` found World Map `(85,113)` with no active path, NPC
  blockers, runtime blockers, or new script error.
- The final Rimuldar return-corridor recovery batch is live-verified
  (`2026-08-28`). Tantegel and Swamp Cave North now recognize exact
  `rimuldar_swamp_cave_north_staging` corridor membership through their
  existing southern-island variants. Before the patch, each had 48 openings
  over the connected 24-step bound, reaching 61 steps for Tantegel and 48 for
  Swamp Cave North. All 170 combinations now retain the requested destination
  with no opening over 14 steps. At `(83,55)`, both start `swamp_cave_south`
  and target `South island west ridge lane` at `(83,54)`, one step north.
  Focused route tests pass `323/323`; Lua syntax, all 33 host-runnable Lua
  suites, all 68 Python tests, speech dependency, and command-queue checks
  pass. Loaded starts retained Swamp Cave North through its dedicated wrapper
  at frame `2454` and Tantegel through its canonical castle chain at frame
  `3522`; both opened the expected nearby return. Shift+U stopped both routes
  cleanly at frames `3009` and `3838`. Tagged readiness passed at frame `6960`;
  fresh frame `7320` found World Map `(83,55)` with no active path, NPC
  blockers, runtime blockers, or new script error. The entire 85-cell corridor
  is now source- and live-verified.
- The third Rimuldar return-corridor recovery batch is live-verified
  (`2026-08-28`). Hauksness, Cantlin, and the Eastern Great Swamp
  Search Area now recognize exact `rimuldar_swamp_cave_north_staging` corridor
  membership through their existing southern-island variants. This reuses
  established route geometry and timing unchanged. Before the patch, each had
  48 overlong openings; at `(83,55)`, each opened `kol_staging` at 25 steps.
  All 255 combinations now retain the requested destination with no opening
  over 14 steps. At `(83,55)`, all three start `swamp_cave_south` and target
  `South island west ridge lane` at `(83,54)`, one step north. Focused route
  tests pass `322/322`; Lua syntax, all 33 host-runnable Lua suites, all 68
  Python tests, speech dependency, and command-queue checks pass. Loaded starts
  retained Hauksness at frames `730` and `3571`, Cantlin at frame `5069`, and
  Great Swamp at frame `5893`; each opened the expected nearby return. Shift+U
  stopped the accepted runs cleanly at frames `4046`, `5456`, and `6221`.
  Tagged readiness passed at frame `8400`; fresh frame `8700` found World Map
  `(83,55)` with no active path, NPC blockers, runtime blockers, or new script
  error.
- The second Rimuldar return-corridor recovery batch is live-verified
  (`2026-08-28`). Kol, Northern Cave, and Mountain Cave now
  recognize exact `rimuldar_swamp_cave_north_staging` corridor membership
  through their existing southern-island variants. This reuses established
  route geometry and timing unchanged. At `(83,55)`, all three retain the
  selected destination, start `swamp_cave_south`, and target `South island west
  ridge lane` at `(83,54)`, one step north, instead of opening 25-48 steps.
  The 85-cell by three-destination regression covers all 255 combinations with
  no opening over 14 steps. Focused route tests pass `321/321`; Lua syntax, all
  33 host-runnable Lua suites, all 68 Python tests, speech dependency, and
  command-queue checks pass. Live starts from World Map `(83,55)` retained the
  three requested destinations at frames `2601`, `3863`, and `4534`, while
  opening `swamp_cave_south` toward `South island west ridge lane`. Shift+U
  stopped each route and autowalk cleanly at frames `3824`, `4334`, and `5013`.
  Tagged readiness passed at frame `9840`; fresh frame `10200` found no active
  path, NPC blockers, or runtime blockers.
- The first Rimuldar return-corridor recovery batch is live-verified
  (`2026-08-28`). Brecconary, Erdrick's Cave, and Garinham now
  recognize exact `rimuldar_swamp_cave_north_staging` corridor membership
  through their existing southern-island variants. This reuses established
  route geometry and timing unchanged. At `(99,49)`, all three retain the
  selected destination, start `rainbow_bridge_return`, and target Swamp Cave
  South at `(104,49)`, five steps east, instead of opening 59-60 steps toward
  the mainland. The 85-cell by three-destination regression covers all 255
  combinations with no opening over 24 steps. Focused route tests pass
  `320/320`; Lua syntax, all 33 host-runnable Lua suites, all 68 Python tests,
  speech dependency, and command-queue checks pass. Loaded starts from World
  Map `(99,49)` selected the expected cave-return leg and waypoint for all
  three destinations at frames `4390`, `5064`, and `6167`; the user confirmed
  every route. Shift+U stopped each route and autowalk cleanly at frames
  `4663`, `5342`, and `6442`. Tagged readiness passed at frame `8760`; fresh
  frame `9660` found no active path, NPC blockers, runtime blockers, or new
  script error.
- Swamp Cave North destination retention across the northern return is
  live-verified (`2026-08-28`). The
  `swamp_cave_northern_return_staging` wrapper now explicitly retains the
  selected Swamp Cave North landmark. This fixes 11 exact Kol/bridge cells
  where the correct short route opened but subsequent route-progress checks
  treated the wrapper as unrelated. At `(96,13)`, the route now remains matched
  to Swamp Cave North and targets `West of Kol north lane` at `(96,21)`, eight
  steps south. Both complete Kol and Tantegel bridge corridor regressions now
  assert destination retention across all 5,824 combinations. Focused route
  tests pass `319/319`; Lua syntax, all 33 host-runnable Lua suites, all 68
  Python tests, speech dependency, and command-queue checks pass. A loaded
  start from World Map `(96,13)` selected the expected return and waypoint at
  frame `1791`. Shift+R reported status on that same route at frame `2110`
  instead of replacing it; Shift+U stopped route and autowalk cleanly at frame
  `2405`. The user confirmed the route. Tagged readiness passed at frame
  `7620`; fresh frame `7920` found no active path, NPC blockers, runtime
  blockers, or new script error.
- The final Mountain Cave spur source batch is live-verified
  (`2026-08-28`). Northern Cave, Hauksness, Cantlin, and Great Swamp now
  recognize exact `mountain_cave` corridor membership through their existing
  northwestern returns. The shared western Swamp Cave staging leg also retains
  Swamp Cave North as its active Travel destination during the nested Mountain
  Cave return. No waypoint geometry or movement timing changed. At `(24,58)`,
  Swamp Cave North and the four newly connected destinations all start
  `mountain_cave_return`, retain the requested destination, and target
  `Mountain Cave south approach` at `(25,58)`, one step east. The complete
  23-cell by 16-destination regression now checks all 368 combinations with no
  opening over 24 steps. Focused route tests pass `319/319`; Lua syntax, all 33
  host-runnable Lua suites, and all 68 Python tests pass. Loaded starts from
  World Map `(24,58)` selected the expected return and waypoint for all five
  destinations at frames `2960`, `3402`, `4661`, `5403`, and `5893`; the user
  confirmed every generated route. Shift+U stopped each route and autowalk
  cleanly at frames `3271`, `3660`, `4909`, `5667`, and `6172`. Tagged
  readiness passed at frame `10380`; fresh frame `10740` found no active path,
  NPC blockers, runtime blockers, or new script error.
- Mountain Cave spur recovery for Swamp Cave South, Rainbow Bridge, and
  Charlock is source-complete and live-verified (`2026-08-28`).
  `swamp_cave_south_mainland` and its western staging leg now recognize exact
  `mountain_cave` corridor membership, preserving the requested final
  destination while reusing the established Mountain Cave, Hauksness, Kol,
  and cave-crossing chain. No waypoint geometry or movement timing changed.
  At `(16,61)`, all three start `mountain_cave_return` and target `Mountain
  Cave forest turn` at `(16,64)`, three steps south, replacing disconnected
  33-step openings toward Charlock island. All 69 combinations of 23 exact
  spur cells and three destinations resolve within 24 steps. Focused route
  tests pass `318/318`; Lua syntax, all 33 host-runnable Lua suites, and all 68
  Python tests pass. Loaded starts from World Map `(16,61)` selected the
  expected route and waypoint for all three destinations at frames `764`,
  `1708`, and `2227`; the user confirmed every generated route and each test
  cancelled cleanly. Tagged readiness passed at frame `4980`; fresh frame
  `5280` found no active path, NPC blockers, runtime blockers, or new script
  error.
- Mountain Cave spur recovery for Brecconary, Erdrick's Cave, and Garinham is
  source-complete and live-verified (`2026-08-28`). Their existing
  western-return variants now recognize exact `mountain_cave` corridor
  membership, preserving the selected destination while reusing
  `mountain_cave_return` and the established nested return chain. No waypoint
  geometry or movement timing changed. At `(16,61)`, all three start
  `mountain_cave_return` and target `Mountain Cave forest turn` at `(16,64)`,
  three steps south, replacing generic 46-48-step openings. All 69 combinations
  of 23 exact spur cells and three destinations resolve within 24 steps.
  Focused route tests pass `317/317`; Lua syntax, all 33 host-runnable Lua
  suites, and all 68 Python tests pass. Loaded starts from World Map `(16,61)`
  selected the expected route and waypoint for all three destinations at
  frames `591`, `1056`, and `1497`; the user confirmed every generated route
  and each test cancelled cleanly. Tagged readiness passed at frame `4560`;
  fresh frame `4860` found no active path, NPC blockers, runtime blockers, or
  new script error.
- The final Garinham bridge-return source batch is live-verified
  (`2026-08-28`). Kol and Northern Cave recognize exact
  `tantegel_garinham_staging` membership through `x <= 13`; Mountain Cave uses
  it only through `x <= 7`. The bounded selectors reuse the established
  `kol_hauksness`, `northern_cave_garinham`, and `mountain_cave_garinham`
  routes without changing waypoint geometry or movement timing. At `(7,3)`,
  Kol selects `kol_hauksness`; Northern Cave and Mountain Cave select
  `tantegel_garinham_staging`. All three target `Garinham north coast lane` at
  `(14,3)`, seven steps east. The complete 82-cell by 16-destination corridor
  regression now checks 1,312 combinations with no opening over 24 steps.
  Focused route tests pass `316/316`; Lua syntax, all 33 host-runnable Lua
  suites, and all 68 Python tests pass. Loaded starts from World Map `(7,3)`
  selected the expected route and waypoint for Kol, Northern Cave, and
  Mountain Cave at frames `1147`, `3860`, and `5098`; the user confirmed all
  three generated correctly. Tagged readiness passed at frame `23100`. Fresh
  frame `23460` found no active autowalk path, NPC blockers, or runtime
  blockers; the final Kol route remains selected.
- Garinham bridge-return cave access is source-complete and live-verified
  (`2026-08-28`). Swamp Cave North, Swamp Cave South, Rainbow
  Bridge, and Charlock now recognize exact `tantegel_garinham_staging`
  membership on its Garinham-exclusive `x <= 24` section. At `(14,4)`, all four
  start that established return and target `Garinham shoulder east step` at
  `(15,4)`, one step east, replacing generic or disconnected 25-88-step
  openings. The bounded region preserves shared Erdrick-corridor selection, and
  no waypoint geometry or movement timing changed. All 328 combinations of 82
  exact corridor cells and four destinations resolve within 24 steps. The full
  corridor audit drops from 150 failures to 21; those remaining flags are a
  separate Kol/Northern/Mountain batch. Focused route tests pass `315/315`;
  Lua syntax, all 33 host-runnable Lua suites, and all 68 Python tests pass.
  Loaded starts from World Map `(14,4)` selected
  `tantegel_garinham_staging` and `Garinham shoulder east step` for all four
  destinations at frames `3067`, `3473`, `4530`, and `5011`. The user confirmed
  every generated route and each test cancelled cleanly. Tagged readiness
  passed at frame `7380`; fresh frame `7800` confirmed path target nil and no
  NPC or runtime blockers.
- Tantegel bridge-return corner recovery is source-complete and live-verified
  (`2026-08-28`). The reverse bridge wrapper includes six proven
  cells omitted by the forward `kol_staging` L-turn: `(32,21)` through
  `(32,24)`, plus `(33,24)` and `(34,24)`. Swamp Cave South Entrance, Rainbow
  Bridge, and Charlock now select the existing connected mainland route from
  those exact cells. At `(32,22)`, all three start `kol_staging` and target
  `North ridge bend` at `(32,19)`, three steps north, replacing 38-43-step
  openings toward Charlock. No waypoint geometry or movement timing changed.
  The three identical 176-cell by 16-destination wrapper audits now have zero
  failures across 8,448 combinations and a maximum opening of 24. Focused
  route tests pass `314/314`; Lua syntax, all 33 host-runnable Lua suites, and
  all 68 Python tests pass. Loaded starts from World Map `(32,22)` selected
  `kol_staging` and `North ridge bend` for Swamp Cave South, Rainbow Bridge,
  and Charlock at frames `1179`, `1999`, and `2376`. The user confirmed all
  three generated correctly and each route cancelled cleanly. Tagged readiness
  passed at frame `6480`; fresh frame `7260` confirmed path target nil and no
  NPC or runtime blockers.
- Swamp-Cave approach-corner recovery is source-complete and live-verified
  (`2026-08-28`). Forward `swamp_cave` geometry includes six cells
  omitted by the reverse corridor's alternate L-turn ordering: `(96,22)`
  through `(96,26)`, plus `(97,26)`. Brecconary, Erdrick's Cave, and Garinham
  now select their connected north-cave return only on that bounded region;
  Swamp Cave South Entrance, Rainbow Bridge, and Charlock select the mainland
  cave approach there. At `(96,24)`, the first group starts
  `tantegel_bridge_swamp_cave_staging` and the second starts `swamp_cave`; all
  six target `West of Kol north lane` at `(96,21)`, three steps north. This
  replaces 26-64-step synthetic openings without changing route geometry or
  movement timing. The three 63-cell by 16-destination corridor audits now
  have zero failures across 3,024 combinations and a maximum opening of 13.
  The completed Kol-corridor audit also covers all 3,008 combinations of 188
  cells and 16 destinations within its 24-step bound. Focused route tests pass
  `313/313`; Lua syntax, all 33 host-runnable Lua suites, and all 68 Python
  tests pass. Loaded starts from World Map `(96,24)` selected the expected
  early-return route for Brecconary, Erdrick's Cave, and Garinham at frames
  `1370`, `4879`, and `5431`; Swamp Cave South, Rainbow Bridge, and Charlock
  selected `swamp_cave` at frames `6518`, `7308`, and `7760`. All six targeted
  `West of Kol north lane`, the user confirmed each generated route, and every
  test cancelled cleanly. Fresh frame `14820` confirmed path target nil and no
  NPC or runtime blockers.
- Early-destination recovery from the eastern Tantegel-to-Kol corridor is
  source-complete and live-verified (`2026-08-28`). Brecconary,
  Erdrick's Cave, and Garinham now recognize exact `kol_staging` membership in
  the bounded region `x >= 47, y <= 37` through their existing Kol-origin
  variants. Static acceptance from `(91,37)` starts
  `tantegel_bridge_staging`, preserves the final Travel object, and targets
  `Kol southwest bridge` at `(90,37)`, one step west, replacing 47- or 48-step
  synthetic openings. Direct local starts near Tantegel, Brecconary, and
  Erdrick's Cave remain unchanged, and exact bridge-return membership preserves
  the known 18-step segment from `(84,26)`. No waypoint geometry, movement
  timing, or downstream itinerary changed. A 188-cell by three-destination
  audit found all 564 selections resolve within the existing 24-step staging
  bound. Focused route tests pass `311/311`; Lua syntax, all 33 host-runnable
  Lua suites, and all 68 Python tests pass. Loaded starts from `(91,37)` at
  frames `4442`, `5069`, and `5593` selected `tantegel_bridge_staging` and `Kol
  southwest bridge` while retaining Brecconary, Erdrick's Cave, and Garinham
  respectively. The user confirmed all three generated correctly; the first
  two cancelled cleanly. Fresh frame `7740` confirmed World Map `(91,37)`, path
  target nil, zero NPC or runtime blockers, and no new script error.
- Final-progression recovery from the Tantegel-to-Kol corridor is
  source-complete and live-verified (`2026-08-28`). Swamp Cave
  South Entrance, Rainbow Bridge, and Charlock now recognize exact
  `kol_staging` membership through the existing mainland cave-crossing
  selector. Static acceptance from `(32,13)` starts `kol_staging`, preserves
  the final Travel object, and targets `North Alefgard west road` at `(35,13)`,
  three steps east, replacing a 51-step `charlock_return` opening. No waypoint
  geometry, movement timing, or downstream itinerary changed. A 188-cell by
  three-destination audit found all 564 selections resolve with no opening
  longer than the existing validated 19-step Kol segment. Focused route tests
  pass `310/310`; Lua syntax, all 33 host-runnable Lua suites, and all 68 Python
  tests pass. Loaded starts from `(32,13)` at frames `4119`, `5284`, and `6370`
  selected `kol_staging` and `North Alefgard west road` while retaining Swamp
  Cave South, Rainbow Bridge, and Charlock respectively. The user confirmed all
  three generated correctly; the first two cancelled cleanly. Fresh frame
  `10200` confirmed World Map `(32,13)`, path target nil, zero NPC or runtime
  blockers, and no new script error.
- Tantegel recovery from the Magic-Temple-to-Rimuldar corridor is
  source-complete and live-verified (`2026-08-28`). Exact
  `rimuldar_magic_temple` membership now selects the existing
  `tantegel_magic_temple` itinerary. From `(107,113)`, static acceptance starts
  `rimuldar_magic_temple_staging`, preserves Tantegel Castle as the final
  Travel object, and targets `Temple south approach east` at `(107,114)`, one
  step south, replacing an unrelated 18-step `cantlin_return_staging` opening.
  No waypoint geometry or movement timing changed. A complete 72-cell by
  16-destination audit found zero flagged selections or errors, with a maximum
  opening of 13 steps. Focused route tests pass `309/309`; Lua syntax, all 33
  host-runnable Lua suites, and all 68 Python tests pass. The loaded selection
  at `(107,113)` started `rimuldar_magic_temple_staging` at frame `1698`,
  targeted `Temple south approach east`, and retained the Tantegel itinerary
  through `staged_from=tantegel_kol`. The user confirmed the generated route.
  Fresh frame `6840` confirmed World Map `(107,113)`, path target nil, zero NPC
  or runtime blockers, and no current script error.
- Northern-access recovery from the Magic-Temple-to-Rimuldar corridor is
  source-complete and live-verified (`2026-08-28`). Kol, Northern
  Cave, Mountain Cave, and Swamp Cave North Entrance now recognize exact
  `rimuldar_magic_temple` membership through their existing south-island route
  variants. Static acceptance from `(107,113)` starts
  `rimuldar_magic_temple_staging`, preserves the final Travel object, and
  targets `Temple south approach east` at `(107,114)`, one step south, replacing
  rejected cross-world openings. No waypoint geometry or movement timing
  changed. A 72-cell by four-destination audit found all 288 selections resolve
  with no opening longer than the existing validated 13-step southern-road
  segment. Loaded selections from `(107,113)` retained Kol, Northern Cave,
  Mountain Cave, and Swamp Cave North Entrance while starting the expected
  Rimuldar leg at frames `3026`, `3752`, `4822`, and `5938`; each targeted
  `Temple south approach east`, one south, and cancelled cleanly. Fresh frame
  `24120` confirmed World Map `(107,113)`, path target nil, zero NPC or runtime
  blockers, and no current script error.
- Western-destination recovery from the Magic-Temple-to-Rimuldar corridor is
  source-complete and live-verified (`2026-08-28`). Hauksness,
  Cantlin, and the Eastern Great Swamp Search Area now recognize exact
  `rimuldar_magic_temple` membership through their existing south-island route
  variants. Static acceptance from `(107,113)` starts
  `rimuldar_magic_temple_staging`, preserves the final Travel object, and
  targets `Temple south approach east` at `(107,114)`, one step south, replacing
  an 89-step synthetic failure toward `Kol south road east lane`. No waypoint
  geometry or movement timing changed. A 72-cell by three-destination audit
  found all 216 selections resolve with no opening longer than the existing
  validated 13-step southern-road segment. Focused route tests pass `307/307`;
  Lua syntax, all 33 host-runnable Lua suites, and all 68 Python tests pass.
  Loaded starts from `(107,113)` at frames `4238`, `6076`, and `7192` selected
  `rimuldar_magic_temple_staging` and `Temple south approach east` while
  retaining Hauksness, Cantlin, and the Eastern Great Swamp Search Area
  respectively. The user confirmed all three generated correctly, and each
  route cancelled cleanly. Fresh frame `11280` confirmed World Map `(107,113)`,
  path target nil, zero NPC or runtime blockers, and no new script error.
- Early-destination recovery from the Magic-Temple-to-Rimuldar corridor is
  source-complete and live-verified (`2026-08-28`). Brecconary,
  Erdrick's Cave, and Garinham now recognize exact `rimuldar_magic_temple`
  membership through their existing south-island route variants. Static
  acceptance from `(107,113)` starts `rimuldar_magic_temple_staging`, preserves
  the final Travel object, and targets `Temple south approach east` at
  `(107,114)`, one step south, replacing synthetic 131- or 132-step failures.
  No waypoint geometry or movement timing changed. A 72-cell by
  three-destination audit found all 216 selections resolve with no opening
  longer than the existing validated 13-step southern-road segment. Focused
  route tests pass `306/306`; Lua syntax, all 33 host-runnable Lua suites, and
  all 68 Python tests pass. Loaded starts from `(107,113)` at frames `4882`,
  `7989`, and `8378` selected `rimuldar_magic_temple_staging` and `Temple south
  approach east` while retaining Brecconary, Erdrick's Cave, and Garinham
  respectively. The user confirmed all three generated correctly, and each
  route cancelled cleanly. Fresh frame `11760` confirmed World Map `(107,113)`,
  path target nil, zero NPC or runtime blockers, and no new script error.
- Final-progression recovery from the Magic-Temple-to-Rimuldar corridor is
  source-complete and live-verified (`2026-08-28`). Swamp Cave
  South Entrance, Rainbow Bridge, and Charlock now recognize exact
  `rimuldar_magic_temple` membership through the temple-origin cave-return
  variant. Static acceptance from `(105,114)` starts
  `rimuldar_magic_temple_staging`, preserves the final Travel object, and
  targets `Temple south approach west` at `(104,114)`, one step west, replacing
  the synthetic 44-step opening toward `Rimuldar east gate lane`. A four-tile
  exclusion around Rimuldar `(102,72)` preserves its direct local cave return.
  No waypoint geometry or movement timing changed. A 72-cell by
  three-destination audit found all 216 selections resolve through the temple
  return or correct local cave route, with no synthetic opening longer than
  the existing validated 13-step southern-road segment. Focused route tests
  pass `305/305`; Lua syntax, all 33 host-runnable Lua suites, and all 68
  Python tests pass. Loaded starts from `(105,114)` at frames `2072`, `2591`,
  and `2944` selected `rimuldar_magic_temple_staging` and `Temple south
  approach west` while retaining Swamp Cave South, Rainbow Bridge, and Charlock
  respectively. The user confirmed all three behaved correctly, and each route
  cancelled cleanly. Fresh frame `5820` confirmed World Map `(105,114)`, path
  target nil, zero NPC or runtime blockers, and no new script error.
- Western-destination recovery from the Erdrick corridor is source-complete
  and live-verified (`2026-08-27`). Hauksness, Cantlin, and the
  Eastern Great Swamp Search Area now use an eleven-step off-network staging
  boundary before joining their shared western route. Static acceptance from
  `(44,36)` starts `kol_staging`, preserves the final Travel object, and
  targets `Bridge south bend` at `(44,38)`, two steps south, replacing the
  synthetic 24-step opening north to `North Alefgard east road`. Exact
  Hauksness-route membership remains direct beyond the new boundary, including
  the existing 19-step forward segment from `(84,27)`. No waypoint geometry or
  movement timing changed. A 57-cell by three-destination audit found all 171
  selections resolve with no opening over 11 steps. Focused route tests pass
  `304/304`; Lua syntax, all 33 host-runnable Lua suites, and all 68 Python
  tests pass. Loaded starts from `(44,36)` at frames `5287`, `7467`, and `8030`
  selected `kol_staging` and `Bridge south bend` while retaining Hauksness,
  Cantlin, and Great Swamp continuations respectively. The user confirmed all
  three generated as expected. Each active route cancelled cleanly; an extra
  stop at frame `7370` correctly reported no route active. Fresh frame `11640`
  confirmed World Map `(44,36)`, path target nil, zero NPC or runtime blockers,
  and no new script error.
- Final-progression recovery from the Erdrick corridor is source-complete and
  live-verified (`2026-08-27`). Swamp Cave South Entrance, Rainbow
  Bridge, and Charlock now recognize exact `erdrick`-corridor membership
  through the mainland cave-crossing selector. Static acceptance from
  `(28,17)` starts `kol_staging`, preserves the final Travel object, and
  targets `North trail marker` at `(28,20)`, three steps south, replacing the
  incorrect `charlock_return` selection and its 51-step opening. Object and
  alias starts are covered; no waypoint geometry or movement timing changed.
  A 57-cell by three-destination audit found zero `charlock_return` selections
  and no opening over 9 steps. Focused route tests pass `302/302`; Lua syntax,
  all 33 host-runnable Lua suites, and all 68 Python tests pass. Loaded starts
  from `(28,17)` at frames `2673`, `5044`, and `5530` selected `kol_staging`
  and `North trail marker` while retaining Swamp Cave South, Rainbow Bridge,
  and Charlock respectively. The user confirmed all three generated as
  expected, and each route cancelled cleanly. Fresh frame `9900` confirmed
  World Map `(28,17)`, path target nil, zero NPC or runtime blockers, and no
  new script error.
- Final-progression recovery from the Swamp-Cave-to-Kol corridor is
  source-complete and live-verified (`2026-08-27`). Swamp Cave
  South Entrance, Rainbow Bridge, and Charlock now recognize exact membership
  on `kol_swamp_cave_staging` through the existing mainland cave-crossing
  selector. Static checks from `(99,42)` preserve each final destination,
  start `swamp_cave_bridge`, and target `Swamp Cave lower swamp turn` at
  `(97,42)`, two steps west, instead of selecting the disconnected
  southern-island route. From `(96,14)`, each starts `swamp_cave` and targets
  `West of Kol north lane` at `(96,21)`, seven steps south, replacing the
  former 38-step opening. The physical north entrance retains its dedicated
  safe re-entry route. A 62-cell by three-destination audit found no direct
  `swamp_cave_south` selections and no opening over 10 steps. Focused route
  tests pass `301/301`; Lua syntax, `git diff --check`, all 33 host-runnable
  Lua suites, and all 68 Python tests pass. Loaded starts from `(99,42)` at
  frames `533`, `1183`, and `2853` selected `swamp_cave_bridge` and the lower
  swamp turn while retaining Swamp Cave South, Rainbow Bridge, and Charlock;
  Charlock repeated successfully at frame `6042`. From `(96,14)`, Charlock
  started `swamp_cave` at frame `16360` and selected `West of Kol north lane`.
  The user accepted all four checks. Fresh frame `22980` confirmed World Map
  `(96,14)`, path target nil, zero runtime blockers, and no current script
  error. A follow-up comprehensive audit checked all 57 exact Erdrick-corridor
  cells against all 16 Travel destinations: all 912 selections resolve, with
  zero openings above 11 steps. The corridor is closed for this pass.
- The remaining Northern-Cave-return northwestern recovery batch is
  source-complete and live-verified (`2026-08-27`). Tantegel,
  Mountain Cave, Hauksness, Cantlin, and the Eastern Great Swamp Search Area
  now recognize exact membership on `kol_rain_shrine_staging` through their
  existing Northern-Cave-origin variants. Static checks from `(78,3)` preserve
  each final Travel object, begin the shrine-return staging leg, and target
  `Rain shrine island west lane` at `(77,3)`, one step west, replacing the
  previous 19-step opening. Object and alias starts are covered; no waypoint
  geometry or movement timing changed. A 65-cell by 16-destination corridor
  audit found no first segment over 11 tiles. Focused route tests pass
  `300/300`; Lua syntax, `git diff --check`, all 33 host-runnable Lua suites,
  and all 68 Python tests pass. Loaded starts at frames `797`, `4532`, `5711`,
  `6928`, and `8206` selected the expected staging leg and west-lane waypoint
  while preserving Tantegel, Mountain Cave, Hauksness, Cantlin, and Great
  Swamp respectively. The user confirmed all five starting waypoints. Fresh
  frame `16920` confirmed World Map `(78,3)`, path target nil, zero runtime
  blockers, and no current script error.
- Northern-Cave-to-southern-progression corridor recovery is source-complete
  and live-verified (`2026-08-26`). Swamp Cave South Entrance,
  Rainbow Bridge, and Charlock now recognize exact membership on
  `kol_rain_shrine_staging` at the mainland south-entrance and Northern
  Cave-to-Swamp-Cave wrapper layers. Static acceptance from `(78,3)` starts
  `kol_rain_shrine_staging`, preserves the final Travel object, and targets
  `Rain shrine island west lane` at `(77,3)`, one step west, replacing the
  incorrect `rainbow_bridge_return` selection and its 51-step opening. Object
  and alias starts are covered; no waypoint geometry or cave behavior changed.
  Focused route tests pass `299/299`; Lua syntax, `git diff --check`, all 33
  host-runnable Lua suites, and all 68 Python tests pass. Loaded starts at
  frames `3998`, `6767`, and `7267` selected the expected shrine-return leg
  while preserving Swamp Cave South, Rainbow Bridge, and Charlock
  respectively. The first two checks cancelled cleanly. Fresh frame `11880`
  confirmed World Map `(78,3)`, path target nil, zero runtime blockers, and no
  current script error.
- Northern-Cave-to-Kol corridor recovery for Brecconary, Erdrick's Cave, and
  Garinham is source-complete and live-verified (`2026-08-26`). Exact
  membership on `kol_rain_shrine_staging` now selects each existing `*_kol`
  destination variant, while the shared bridge wrapper requires its own
  validated corridor before bypassing the shrine return. Static acceptance
  from `(92,13)` starts `kol_rain_shrine_staging`, preserves the final Travel
  object, and targets `West of Kol forest bend` at `(92,10)`, three steps
  north, replacing the previous 63- or 64-step synthetic opening. Object and
  alias starts are covered; no waypoint geometry changed. Focused route tests
  pass `298/298`; Lua syntax, `git diff --check`, all 33 host-runnable Lua
  suites, and all 68 Python tests pass. Loaded starts at frames `908`, `3146`,
  and `4224` selected the expected staging route and preserved Brecconary,
  Erdrick's Cave, and Garinham respectively; Brecconary repeated successfully
  at frame `5047`. Each check cancelled cleanly. Fresh frame `10200` confirmed
  clear World Map `(92,13)`, path target nil, zero runtime blockers, and no
  current script error.
- The first bounded off-network recovery slice is source-complete and
  live-verified (`2026-08-26`). A Brecconary selection from World Map
  `(99,42)` started `kol_swamp_cave_staging` at frame `454`, preserved
  `staged_from=brecconary_swamp_cave_north`, and targeted `Swamp Cave lower
  swamp turn` at `(97,42)`, two steps west, rather than creating the previous
  52-step synthetic opening. Fresh frame `6420` confirmed that route creation
  did not move the hero: position remained `(99,42)`, path target was nil, and
  runtime blockers were empty. Erdrick's Cave selected the same staging route
  at frame `24501` with `staged_from=erdrick_swamp_cave_north`; after correcting
  an overshot position, the user revalidated it from the exact waypoint
  `(97,42)`, and frame `33254` again selected the expected staging route.
  Garinham then selected it at frame `34251` while preserving
  `staged_from=garinham_swamp_cave_north`. Fresh frame `38280` confirmed World
  Map `(99,42)`, path target nil, and no runtime blockers. The current script
  error file remains unchanged since May. All three destination variants are
  live-accepted. Focused route tests pass `297/297`; Lua syntax,
  `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python tests
  pass.
- Route-control hotkey polish is source-complete and live-verified
  (`2026-08-26`). `Shift+R` now uses the read-only route-status path and never
  starts, replaces, or recalculates guidance; full status moved to `Shift+B`.
  `Shift+U` now clears both active/deferred auto-walk and guided Travel state.
  During the loaded acceptance run, frame `2291` reported the active
  `kol_swamp_cave_staging` route, frame `2787` logged both
  `AUTO_WALK: manually stopped active=true reason=player hotkey` and
  `OVERWORLD_ROUTE: event=stop route=kol_swamp_cave_staging`, and the follow-up
  `Shift+R` logged `event=status route=none` at frame `2909`. Fresh frame
  `7680` confirmed World Map `(99,42)`, path target nil, and zero runtime
  blockers. The user confirmed all player-facing speech and controls behaved
  as expected. Focused hotkey/config/filter and release-guide tests pass; Lua
  syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68
  Python tests pass.
- Great Swamp near-destination routing and terminal stopping are source-complete
  and live-verified (`2026-08-25`). The direct snap is now bounded to the
  proven east-west row `(81..89,112)`; `(80,112)` and `(81,111)` still use the
  connected Kol staging route. From `(82,112)`, auto-walk selected
  `great_swamp_cantlin` index 38 and queued seven eastward steps. The first
  reproduction reached `(89,112)` but the normal 12-frame final press carried
  to `(90,112)`. Terminal arrival now force-releases queued input immediately,
  and the Great Swamp endpoint uses a route-specific 10-frame final press that
  remains in force across ordinary, guarded-twitch, cadence, and timeout
  retries. This avoids the disabled movement-RAM reset path. Final acceptance
  started at frame `3660`, used `inject_limit=10` from `(88,112)` at frame
  `3773`, arrived at `(89,112)` at frame `3784`, and remained there through
  fresh frame `4440`, with target nil and zero NPC/runtime blockers. No drift,
  cancellation, blocker, or runtime-block injection occurred. Focused tests
  pass `146/146` auto-step, `125/125` route-manager, and `296/296` overworld
  route cases; Lua syntax, `git diff --check`, all 33 host-runnable Lua suites,
  and all 68 Python tests pass.
- The final three landmark-origin matrix holes are source-complete and
  live-verified (`2026-08-25`). Garinham `(1,2)` now reaches Erdrick's Cave
  `(28,12)`, Northern Cave `(81,1)`, and Mountain Cave `(29,57)` through
  established route geometry instead of 37- or 38-step synthetic openings.
  Erdrick travel follows the validated eastern road directly; the other two
  routes nest through the existing Garinham return, bridge junction, and Kol
  doorstep before selecting the established destination branch. The full
  16-landmark audit now resolves all 240 directed non-self pairs, with no first
  segment longer than 11 tiles. The complete matrix is now a permanent
  regression. Focused route tests pass `295/295`; Lua syntax,
  `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python tests
  pass. Garinham-to-Erdrick started on `erdrick_garinham` at frame `1646` and
  entered Erdrick's Cave B1 `(0,0)` on frame `3606`. It logged no timing retry,
  blocker, drift, cancellation, replacement, runtime-block injection, or
  current script error. The post-arrival off-direction cleanup is the expected
  map transition. Fresh frame `6780` confirmed path target nil and zero
  NPC/runtime blockers. Garinham-to-Northern-Cave started on
  `tantegel_garinham_staging` at frame `10946`, handed off through
  `kol_garinham_staging` at frame `14501` and `northern_cave_garinham` at
  frame `21173`, then arrived at Northern Cave `(81,1)` on frame `24165`. It
  logged no timing retry, blocker, drift, cancellation, replacement,
  runtime-block injection, or current script error. Fresh frame `277200`
  confirmed path target nil and zero NPC/runtime blockers. Garinham-to-
  Mountain-Cave started on `tantegel_garinham_staging` at frame `283194`,
  handed off through `kol_garinham_staging`,
  `mountain_cave_garinham_connector`, and `mountain_cave_garinham` at frames
  `286622`, `293294`, and `304062`, then arrived at Mountain Cave `(29,57)` on
  frame `304910`. It logged no timing retry, blocker, drift, cancellation,
  replacement, runtime-block injection, or current script error. Fresh frame
  `959280` confirmed path target nil and zero NPC/runtime blockers. The full
  three-run live matrix is accepted, and the focused batch is ready to commit
  and push.
- Final-island travel to the five northwestern destinations is source-complete
  and accepted through its two-route representative live matrix
  (`2026-08-25`). Charlock Castle `(48,48)` and
  Rainbow Bridge `(65,49)` now connect to Northern Cave `(81,1)`, Mountain
  Cave `(29,57)`, Hauksness `(25,89)`, Cantlin `(73,102)`, and the Eastern
  Great Swamp Search Area `(89,112)`. The patch only extends the selection
  anchors of five proven south-origin variants; it adds no waypoint geometry.
  All 10 object and alias selections start on the correct final-island return,
  and a regression follows Charlock-to-Great-Swamp through Swamp Cave, Kol,
  Hauksness, and Cantlin to the final leg. Focused route tests pass `291/291`;
  Lua syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68
  Python tests pass. Charlock-to-Great-Swamp started on `charlock_return` at
  frame `1179`, handed off through Swamp Cave/Kol, Hauksness, and Cantlin at
  frames `5171`, `9080`, `23752`, and `28760`, and arrived at `(89,112)` on
  frame `32552`. One bounded first-step timing retry at `(48,48)->DOWN`
  recovered automatically. No blocker, drift, route cancellation, route
  replacement, runtime-block injection, or current script error occurred.
  Fresh frame `37140` confirmed path target nil and zero NPC/runtime blockers.
  Rainbow-Bridge-to-Mountain-Cave started on `rainbow_bridge_return` at frame
  `743`, handed off through Swamp Cave/Kol and the western connector at frames
  `2335`, `6025`, and `16793`, and arrived at `(29,57)` on frame `17641`. It
  logged no timing retry, blocker, drift, route cancellation, route
  replacement, runtime-block injection, or current script error. Fresh frame
  `29520` confirmed path target nil and zero NPC/runtime blockers. The user
  confirmed both routes had no player-facing issues. The batch is accepted and
  ready to commit and push.
- The 18-case northwestern return batch is source-complete and accepted through
  the full three-run representative live matrix (`2026-08-25`). Northern Cave,
  Mountain Cave, Hauksness, Cantlin,
  and the Eastern Great Swamp Search Area now fill their remaining connections
  to Kol, Northern Cave, Mountain Cave, Hauksness, Cantlin, and Great Swamp as
  applicable. Each route first reuses its origin's proven return to Kol, then
  follows the existing destination geometry; no waypoint geometry changed.
  Six scoped target variants and shared staging routes cover all 18 selections
  without stealing valid local starts. Focused route tests pass `289/289`; Lua
  syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python
  tests pass. Great Swamp `(89,112)` to Northern Cave `(81,1)` started on
  `cantlin_return_staging` at frame `1148`, handed off through Hauksness and
  Kol at frames `4987`, `10155`, and `24827`, and arrived on frame `27819`.
  One automatic first-step timing retry recovered successfully. Two
  final-settle carry steps were explicitly accepted and continued immediately;
  no blocker, route stop, replacement, runtime-block injection, or script
  error occurred. Fresh frame `44400` confirmed path target nil and zero
  runtime blockers. Northern Cave `(81,1)` to Great Swamp `(89,112)` then
  started on `kol_rain_shrine_staging` at frame `52473`, handed off through
  Kol, Hauksness, and Cantlin at frames `55711`, `70383`, and `75391`, and
  arrived on frame `79183`. One automatic first-step timing retry recovered;
  the same two final-settle carry steps were explicitly accepted. No blocker,
  route stop, replacement, runtime-block injection, or script error occurred.
  A later `R` press created an already-arrived route after completion and does
  not affect acceptance. Fresh frame `93480` confirmed path target nil and zero
  runtime blockers. Mountain Cave `(29,57)` to Cantlin `(73,102)` started on
  `mountain_cave_return` at frame `100833`, handed off through Kol and
  Hauksness at frames `101755`, `112539`, and `127211`, and entered map `0x0A`
  on frame `132779`. It had no timing retry, blocker, route stop, replacement,
  runtime-block injection, or script error. The final coordinate mismatch
  cleanup is the expected town-map transition. Fresh frame `139140` confirmed
  path target nil and zero runtime blockers. The user confirmed all three runs
  completed without player-facing issues. The batch is accepted and ready to
  commit and push.
- The 12-case western-to-early-mainland batch is source-complete and accepted
  through the full three-run representative live matrix (`2026-08-24`).
  Hauksness, Mountain Cave, Cantlin, and the Eastern Great Swamp Search Area
  now reach Brecconary, Erdrick's
  Cave, and Garinham through their proven nested returns to Kol, a new derived
  bridge-junction wrapper, and the unchanged short destination legs. No
  waypoint geometry changed. Focused route tests pass `286/286`; Lua syntax,
  `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python tests
  pass. Hauksness `(25,89)` to Garinham started on `kol_return_staging` at
  frame `4681`, handed off west of Kol at `19430`, switched to the unchanged
  Garinham leg at the bridge junction at `26054`, and entered map `0x09` at
  `29526`. It logged no timing retry, blocker, drift, runtime-block injection,
  or script error. Fresh frame `324480` confirmed map `0x09`, path target nil,
  and zero runtime blockers. Mountain Cave `(29,57)` to Erdrick's Cave started
  on `mountain_cave_return` at frame `335011`, handed off to the Kol return at
  `335886`, switched to bridge staging west of Kol at `346670`, activated the
  unchanged Erdrick's Cave leg at the bridge junction at `353294`, and entered
  map `0x1C` at `355022`. It also logged no timing retry, blocker, drift,
  runtime-block injection, or script error. Fresh frame `359280` confirmed B1
  `(0,0)`, path target nil, and zero runtime blockers. The post-arrival route
  cleanup is the expected map transition. Great Swamp `(89,112)` to
  Brecconary started on `cantlin_return_staging` at frame `366069`, handed off
  through Hauksness, Kol, and bridge staging at frames `369912`, `375080`, and
  `389752`, activated the unchanged Brecconary leg at `396376`, and entered
  map `0x08` at `396680`. One bounded retry on `(84,113)->LEFT` at frame
  `366540` crossed successfully at `366585`; no blocker, drift, route stop,
  runtime-block injection, or script error followed. The arrival cleanup at
  `(0,15)` is the expected map transition. The user confirmed all three runs
  completed without noticeable issues. The batch is accepted and was committed
  and pushed as `f49fcb7`.
- The remaining 26-case southern-route batch is source-complete and accepted
  through the full three-run representative live matrix (`2026-08-24`).
  Northern Cave,
  Hauksness, Mountain Cave,
  Cantlin, and the Eastern Great Swamp Search Area now reach Swamp Cave south,
  Rimuldar, Magic Temple, Rainbow Bridge, and Charlock through their proven
  return chains to Kol and Swamp Cave north. Two derived staging wrappers wait
  for automatic entry into map `0x15`; no cave movement is injected and no
  waypoint geometry changed. The separate Magic Temple-to-Swamp-Cave-south
  Travel-selection seam is also fixed. Focused route tests pass `283/283`;
  Lua syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68
  Python tests pass. Northern Cave `(81,1)` to Rainbow Bridge started at frame
  `576`, handed off around Kol at `3879`, reached the Swamp Cave north approach
  at `6439`, resumed from the south exit at `7731`, arrived at `(65,49)` at
  `9218`, and completed auto-walk at `9238`. It logged no route stop, blocker,
  drift, runtime-block injection, or current script error; ordinary turn
  represses moved normally. Mountain Cave `(29,57)` to Magic Temple started at
  frame `21645`, handed off to the Kol return at `22870`, switched to the
  Swamp Cave approach at `33654`, and retained Magic Temple at the cave wait
  on frame `36214`. The hero emerged south at `48677`, handed off from the
  Rimuldar bypass to Magic Temple at `52876`, arrived at `(108,109)` at
  `55740`, and completed auto-walk at `55760`. Two bounded retries on the
  initial `(29,57)->LEFT` step recovered automatically; there was no route
  stop, blocker, drift, runtime-block injection, or script error. A later `R`
  press created a fresh route at frame `57010`, after arrival, and does not
  affect acceptance. Great Swamp `(89,112)` to Charlock started at frame `664`,
  handed off through Cantlin, Hauksness, Kol, and the Swamp Cave approach at
  frames `4370`, `9538`, `24210`, and `26770`. It emerged south and activated
  Charlock at `27860`, then entered Charlock map `0x02` at `31939`. Fresh frame
  `32400` confirmed `(10,19)`, path target nil, and zero NPC/runtime blockers.
  One bounded retry at `(86,113)->LEFT` recovered automatically; no stop,
  blocker, route replacement, runtime-block injection, or script error
  occurred. The cave and castle transition cleanup messages are expected
  cross-map landings, not route failures. The batch is accepted.
- Eastern-mainland connections to the southern island are source-complete and
  live-verified through the full representative matrix (`2026-08-23`).
  Tantegel, Brecconary, Erdrick's
  Cave, Garinham, and Kol now reach Swamp Cave south, Rainbow Bridge, and
  Charlock through their proven Kol and Swamp Cave north corridors, manual map
  `0x15` traversal, and the existing south-side destination legs. Garinham's
  unique repair first reverses the accepted eastern road to bridge junction
  `(44,38)`; it no longer selects `charlock_return` or attempts a 93-step
  synthetic opening. That chain also repairs Garinham travel to Swamp Cave
  north, Rimuldar, and Magic Temple. No waypoint geometry changed. Focused
  route tests pass `282/282`; Lua syntax, `git diff --check`, all 33
  host-runnable Lua suites, and all 68 Python tests pass. Garinham-to-Rainbow-
  Bridge started at frame `1032`, handed off at bridge junction `(44,38)` at
  `4527`, bypassed Kol at `11199`, entered Swamp Cave at `13759`, resumed from
  the south exit at `15025`, and arrived at `(65,49)` at `16624`. It logged no
  retry, route stop, blocker, drift, runtime-block injection, unintended town
  entry, or script error. Tantegel-to-Charlock started at frame `26435`,
  bypassed Kol at `33742`, entered Swamp Cave at `36302`, resumed from the
  south exit at `37378`, and entered Charlock map `0x02` at `41409`, also with
  no retry or anomaly. Kol-to-Swamp-Cave-south started at frame `47035`,
  entered the north cave at `49905`, and arrived on World Map `(104,49)` at
  `51055`, again with no retry or anomaly. The batch is accepted.
- Final-island connections to Brecconary, Erdrick's Cave, and Garinham are
  source-complete and live-verified (`2026-08-23`). Charlock Castle
  `(48,48)` previously selected the nearby-looking raw mainland routes across
  impassable water, while Rainbow Bridge `(65,49)` selected raw 25-26-step
  openings. The three south-island variants now recognize both anchors and
  require a proven corridor before joining their final route. Charlock uses
  `charlock_return`, Rainbow Bridge uses `rainbow_bridge_return`, and both
  preserve the selected destination through automatic Swamp Cave entry and
  manual traversal before reusing the accepted Kol and bridge-junction
  bypasses. No waypoint geometry changed. Focused route tests pass `281/281`;
  Lua syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68
  Python tests pass. Charlock-to-Brecconary entered map `0x08` at frame
  `16555`; Rainbow-Bridge-to-Erdrick's-Cave entered map `0x1C` at `40554`;
  Charlock-to-Garinham arrived at frame `82491`. All three routes crossed
  Swamp Cave, bypassed Kol, and completed without a route stop, blocker, drift,
  unintended town entry, runtime-block injection, or script error. The first
  two runs recovered from one `(104,44)->UP` cadence retry; the Garinham run
  recovered after two retries at that known timing seam.
- Final-island northern-access connections are source-complete and live-
  verified through a representative matrix (`2026-08-23`). Charlock-to-Kol
  started at frame `690`, entered Swamp Cave and activated the direct Kol
  continuation at frame `5770`, emerged north at frame `15975`, and entered
  Kol map `0x07` at frame `19593`. One initial retry recovered automatically.
  The known `(104,44)->UP` timing seam exhausted two retries and stopped at
  frame `16778`; an unchanged-origin restart crossed successfully without a
  runtime blocker. Rainbow-Bridge-to-Swamp-Cave-north started at frame `30595`,
  activated the north-exterior continuation on cave entry at frame `32481`,
  and arrived at frame `34015`. Two cadence retries at `(70,50)->UP` and two
  interior retries at `(0,29)->RIGHT` recovered automatically without a stop.
  Together the runs exercised both origin returns and both destination
  continuations; regressions cover all four cross-combinations. Neither run
  logged drift, route replacement, runtime-block injection, unintended map
  entry, or script error. No waypoint geometry changed. Focused route tests
  pass `280/280`; Lua syntax, `git diff --check`, all 33 host-runnable Lua
  suites, and all 68 Python tests pass.
- Magic-Temple-origin connections to Cantlin and the Eastern Great Swamp
  Search Area are source-complete and live-verified (`2026-08-23`). From World
  Map `(108,109)`, both used the proven Magic Temple return, bypassed Rimuldar,
  crossed Swamp Cave manually, and bypassed Kol and Hauksness. Cantlin started
  at frame `1923`, bypassed Rimuldar at frame `4939`, entered Swamp Cave at
  frame `8603`, resumed north at frame `10340`, bypassed Kol at frame `13730`,
  bypassed Hauksness at frame `28402`, and entered map `0x0A` at frame `33970`.
  One ordinary timing retry and two north-exit cadence retries recovered
  automatically. Great Swamp started at frame `41800`, bypassed Rimuldar at
  frame `44821`, entered Swamp Cave at frame `48485`, resumed north at frame
  `49732`, bypassed Kol at frame `53042`, Hauksness at frame `67714`, and
  Cantlin at frame `72722`, then arrived at `(89,112)` at frame `76514`.
  Continuous autowalk stopped normally at frame `76534`; no timing retry
  occurred. Neither run logged a blocker, drift, cancellation, runtime-block
  injection, unintended town entry, or script error. No waypoint geometry
  changed. Focused route tests pass `279/279`; Lua syntax, `git diff --check`,
  all 33 host-runnable Lua suites, and all 68 Python tests pass.
- Magic-Temple-origin connections to Kol and Swamp Cave north are
  source-complete and live-verified (`2026-08-23`). From World Map `(108,109)`,
  both began on the proven Magic Temple return, bypassed Rimuldar at `(103,72)`,
  approached Swamp Cave south, and retained the selected destination during
  manual map `0x15` traversal. The Swamp Cave north run started at frame `832`,
  handed off at Rimuldar at frame `3827`, selected its north-exterior route on
  cave entry at frame `7491`, and arrived after emerging at frame `8639`. The
  Kol run started at frame `14249`, handed off at Rimuldar at frame `17159`,
  selected its direct north-exit-to-Kol route on cave entry at frame `20823`,
  and entered Kol at frame `28474`. One internal cave-step timing retry occurred
  in each run; Kol also had two internal cadence retries on the first
  north-exterior step. All recovered automatically, with no blocker, drift,
  cancellation, runtime-block injection, or script error. No waypoint geometry
  changed. Focused route tests pass `278/278`; Lua syntax, `git diff --check`,
  all 33 host-runnable Lua suites, and all 68 Python tests pass.
- Magic-Temple-origin connections to Northern Cave, Hauksness, and Mountain
  Cave are source-complete and live-verified (`2026-08-23`). From World Map
  `(108,109)`, all three now use the proven Magic Temple return, bypass Rimuldar
  at east doorstep `(103,72)`, retain the destination during manual Swamp Cave
  traversal, resume from north exit `(104,44)`, bypass Kol, and use their
  unchanged final routes. No waypoint geometry changed. Northern Cave started
  at frame `822`, bypassed Rimuldar at frame `3770`, entered Swamp Cave at frame
  `7434`, bypassed Kol at frame `11227`, and arrived at `(81,1)` on frame
  `14219` with no timing retries. Hauksness started at frame `20657`, bypassed
  Rimuldar at frame `23665`, entered Swamp Cave at frame `27329`, bypassed Kol
  at frame `32368`, and entered map `0x03` at `(0,10)` on frame `47088`, also
  without a timing retry. Mountain Cave started at frame `51415`, bypassed
  Rimuldar at frame `54419`, entered Swamp Cave at frame `58083`, bypassed Kol
  at frame `62287`, activated its final spur at frame `73055`, and entered map
  `0x16` at `(0,7)` on frame `73903`. It recovered one bounded timing retry on
  `(108,109)->DOWN`, two on `(0,29)->RIGHT` inside the cave, and one on north
  exit `(104,44)->UP`; none stopped the route. No run logged a blocker, drift,
  cancellation, runtime-block injection, unintended town entry, or script
  error. Focused route tests pass `277/277`; Lua syntax, `git diff --check`, all
  33 host-runnable Lua suites, and all 68 Python tests pass. This batch was
  committed and pushed as `d986f45`.
- Magic-Temple-origin connections to Brecconary, Erdrick's Cave, and Garinham
  are source-complete and live-verified (`2026-08-23`). The old
  selection from World Map `(108,109)` incorrectly chose raw direct routes.
  Each destination now starts on the proven Magic-Temple-to-Rimuldar return,
  bypasses Rimuldar at `(103,72)`, continues to Swamp Cave south, retains the
  selected destination during manual map `0x15` traversal, then reuses the
  established Kol bypass and Tantegel bridge junction before its unchanged
  final leg. No waypoint geometry changed. The Brecconary run started at frame
  `3262`, bypassed Rimuldar at frame `6724`, entered Swamp Cave at frame
  `10388`, resumed north at frame `12328`, bypassed Kol at frame `15558`, and
  entered Brecconary map `0x08` at frame `22486`. No timing retry, blocked
  step, drift, route replacement, runtime-block injection, or script error was
  logged. Erdrick's Cave started at frame `33516`, bypassed Rimuldar at frame
  `36455`, entered Swamp Cave at frame `40119`, resumed north at frame `41340`,
  bypassed Kol at frame `44074`, and entered map `0x1C` at frame `52426`.
  Fresh frame `54060` confirmed `(0,0)`, path target nil, and zero NPC/runtime
  blockers; it also had no retry, blocked step, drift, replacement, runtime
  injection, or script error. Garinham started at frame `57635`, bypassed
  Rimuldar at frame `62367`, entered Swamp Cave at frame `66031`, resumed north
  at frame `67543`, bypassed Kol at frame `70293`, and entered map `0x09` at
  frame `80389`. It recovered one bounded timing retry on the initial
  `(108,109)->DOWN` step and one on the first interior cave step. Fresh frame
  `82740` confirmed `(0,14)`, path target nil, and zero runtime blockers. No run
  in the batch logged a blocker, drift, route replacement, runtime injection,
  unintended intermediate town entry, or script error. Focused route tests
  pass `276/276`; Lua syntax,
  `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python tests
  pass. This three-route batch was committed and pushed as `aee90a7`.
- Rimuldar-origin connections to Swamp Cave north and Kol are source-complete
  and live-verified (`2026-08-23`). Both start at World Map `(102,72)`, follow
  the proven route to Swamp Cave south, retain the selected destination during
  manual map `0x15` traversal, and resume at north exit `(104,44)`. Swamp Cave
  north completed on emergence at frame `10283`; final frame `12300` confirmed
  `(104,44)`, path target nil, and zero runtime blockers. Kol handed off on cave
  entry at frame `19197`, resumed outside the north exit at frame `20256`,
  entered map `0x07` at frame `23038`, and final frame `25620` confirmed
  `(19,23)`, path target nil, and zero runtime blockers. Neither run logged a
  timing retry, blocker stop, route replacement, runtime-block injection, or
  script error. Focused route tests pass `274/274`; Lua syntax,
  `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python tests
  pass.
- Rimuldar-origin connections to Cantlin and the Eastern Great Swamp Search
  Area are source-complete and live-verified (`2026-08-23`). From World Map
  `(102,72)`, both preserve the selected destination through Swamp Cave map
  `0x15`, resume from north exit `(104,44)`, bypass Kol and Hauksness, and use
  their established final approaches. Cantlin entered map `0x0A` at frame
  `32741` and ended clear at `(15,0)`. It needed manual restarts after timing
  stops on `(102,72)->RIGHT` and `(104,44)->UP`, then crossed both edges.
  Great Swamp handed off outside Kol at frame `74259`, outside Hauksness at
  frame `88931`, activated its final leg at frame `93939`, and arrived at
  `(89,112)` at frame `97731`; its one timing retry at `(104,44)->UP`
  recovered without stopping. No blocker was promoted, and neither run showed
  route drift, runtime-block injection, unintended town entry, or a script
  error. Pressing `R` at frame `101644` created a new route after Great Swamp
  arrival, so it does not affect acceptance. Focused route tests pass
  `271/271`; Lua syntax, `git diff --check`, all 33 host-runnable Lua suites,
  and all 68 Python tests pass.
- Rimuldar-origin connections to Northern Cave, Hauksness, and Mountain Cave
  are source-complete and live-verified (`2026-08-23`). From World Map
  `(102,72)`, all three reuse the proven Rimuldar-to-Swamp-Cave return, retain
  the selected destination through manual map `0x15` traversal, resume from
  north exit `(104,44)`, and bypass Kol at `(103,10)`. Northern Cave arrived at
  World Map `(81,1)` at frame `12314`; Hauksness entered map `0x03` at frame
  `44389` and ended at `(0,10)`; Mountain Cave entered map `0x16` at frame
  `141545` and ended at `(0,7)`. All final audits found path target nil and
  zero runtime blockers. Northern Cave and Hauksness had no timing retries;
  Mountain Cave recovered two bounded retries on its first
  `(102,72)->RIGHT` step. No run logged a blocked step, cancellation, route
  replacement, runtime-block injection, or unintended town entry. Focused
  route tests pass `270/270`; Lua syntax, `git diff --check`, all 33
  host-runnable Lua suites, and all 68 Python tests pass.
- Rimuldar-origin connections to Brecconary, Erdrick's Cave, and Garinham are
  source-complete and live-verified (`2026-08-23`). From World Map `(102,72)`,
  all three bypass Rimuldar, preserve the selected destination through Swamp
  Cave map `0x15`, resume from north exit `(104,44)`, and reuse the established
  Kol and Tantegel bridge staging routes. Brecconary arrived on map `0x08` and
  ended clear at `(0,15)`; Erdrick's Cave arrived on map `0x1C` and ended clear
  at `(0,0)`; Garinham entered map `0x09` at frame `115261`, with final frame
  `138600` confirming `(0,14)`, path target nil, and zero runtime blockers. At
  Garinham's north-exit restart, `(104,44)->UP` stopped twice after bounded
  timing retries. The first `U` restart did not move the hero; the second
  crossed the same edge, and continuous autowalk then completed normally. The
  noisy edge was not promoted as a permanent blocker. No run showed route
  drift, runtime-block injection, unintended town entry, or a script error.
  Focused route tests pass `269/269`; Lua syntax, `git diff --check`, all 33
  host-runnable Lua suites, and all 68 Python tests pass.
- Swamp-Cave-South connections to Cantlin and the Eastern Great Swamp Search
  Area are source-complete and live-verified (`2026-08-23`). Both preserve the
  final destination through automatic cave entry and manual map `0x15`
  traversal, resume from north exit `(104,44)`, bypass Kol at `(103,10)`, and
  reuse the established Hauksness approach. Cantlin handed off from Hauksness
  staging at frame `22401`, entered map `0x0A` at frame `27969`, and ended at
  `(15,0)` with path target nil and zero runtime blockers. Great Swamp handed
  off to Cantlin staging at frame `20363`, activated its final leg at frame
  `25371`, and arrived at World Map `(89,112)` at frame `29163`. Final frame
  `69960` confirmed path target nil and zero NPC/runtime blockers. Each run
  recovered two timing retries at `(104,44)->UP`; both also accepted the same
  two intentional continuous-walk carry steps in the western forest. Neither
  run had a blocked edge, cancellation, runtime injection, unintended town
  entry, or script error. Focused route tests pass `268/268`; Lua syntax,
  `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python tests
  pass.
- Swamp-Cave-South connections to Northern Cave, Hauksness, and Mountain Cave
  are source-complete and live-verified (`2026-08-21`). Each selection from
  World Map `(104,49)` waits for automatic Swamp Cave entry, preserves the
  final destination during the manual map `0x15` crossing, resumes on
  `kol_swamp_cave_staging` at north exit `(104,44)`, and bypasses Kol at west
  doorstep `(103,10)`. Northern Cave handed off outside Kol at frame `8191`,
  arrived at `(81,1)` at frame `11183`, and ended with route/path nil and zero
  blockers at frame `13680`. Hauksness handed off outside Kol at frame
  `21498`, entered map `0x03` at frame `36218`, and ended at `(0,10)` with
  route/path nil and zero blockers at frame `150660`. Mountain Cave handed off
  outside Kol at frame `160089`, handed off from the shared western-desert
  connector at frame `170857`, entered map `0x16` at frame `171705`, and ended
  at `(0,7)` with route/path nil and zero blockers at frame `193260`. Northern
  Cave and Mountain Cave each had one recovered timing retry on
  `(104,44)->UP`; Hauksness had none. No run produced route drift,
  cancellation, a blocked edge, runtime-block injection, or an unintended
  town entry. Focused route tests pass `266/266`; Lua syntax,
  `git diff --check`, all 33 host-runnable Lua suites, and all 68 Python tests
  pass.
- Near-destination route snapping is source-complete and live-verified
  (`2026-08-21`). The staging audit found four player-facing destinations whose
  strict corridor guard could select a distant return route even when the hero
  was within five tiles of the destination: Rainbow Bridge, Charlock Castle,
  Mountain Cave, and the Eastern Great Swamp Search Area. Those staging
  configurations now opt into local nearest-waypoint starts while preserving
  distant corridor staging and the mandatory manual crossing between the two
  Swamp Cave entrances. Manual FCEUX runs started and arrived directly at
  Rainbow Bridge from `(63,49)` in 2 steps, Charlock from `(46,48)` in 2 steps,
  Mountain Cave from `(25,57)` in 4 steps, and Great Swamp from `(87,112)` in
  2 steps. None logged `staged_from`, cancellation, blocker injection, or a
  script error. Final frame `16740` confirmed clear World Map `(62,49)`, path
  target nil, and zero runtime blockers. Focused route tests pass `264/264`;
  Lua syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68
  Python tests pass.
- Swamp-Cave-South to Garinham is source-complete and live-verified
  (`2026-08-21`). From World Map `(104,49)`, Garinham now remains selected
  through automatic Swamp Cave entry and the manual map `0x15` crossing, then
  composes the accepted north-exit Kol bypass and bridge connector into the
  unchanged Garinham corridor. Frame `4629` entered Swamp Cave, frame `10217`
  bypassed Kol at west doorstep `(103,10)`, frame `16841` activated the final
  leg at bridge junction `(44,38)`, and frame `20313` entered Garinham map
  `0x09`. Final frame `21360` confirmed `(0,14)`, path target nil, and zero
  runtime blockers. The full route had no timing retry, blocked step, drift,
  cancellation, replacement, unintended intermediate town entry,
  runtime-block injection, or script error. Focused route tests pass `262/262`;
  Lua syntax and the full gate pass all 33 host-runnable Lua suites plus all 68
  Python tests.
- Swamp-Cave-South to Erdrick's Cave is source-complete and live-verified
  (`2026-08-21`). From World Map `(104,49)`, the selected destination now
  survives automatic Swamp Cave entry and the manual map `0x15` crossing, then
  composes the established north-exit Kol bypass and bridge connector into the
  unchanged Erdrick corridor. Frame `4449` entered Swamp Cave and activated
  `kol_swamp_cave_staging`; frame `10277` bypassed Kol at west doorstep
  `(103,10)`; frame `16901` handed off at bridge junction `(44,38)`; and frame
  `18629` entered Erdrick's Cave B1 map `0x1C`. Final frame `20040` confirmed
  `(0,0)`, path target nil, and zero NPC/runtime blockers. The full route had
  no timing retry, blocked step, drift, cancellation, route replacement,
  unintended town entry, runtime-block injection, or script error. Focused
  route tests pass `261/261`; Lua syntax and the full gate pass all 33
  host-runnable Lua suites plus all 68 Python tests.
- Swamp-Cave-South to Brecconary is source-complete and live-verified
  (`2026-08-21`). A Brecconary selection from World Map `(104,49)` now waits
  for automatic Swamp Cave entry, preserves the destination through map `0x15`,
  then composes the established north-exit Kol bypass and bridge connector into
  the unchanged Brecconary arrival leg. Pressing `R` at north exit `(104,44)`
  initially replaced the itinerary with the physical Swamp Cave route; the Kol
  staging leg now treats that Travel object as compatible, so refresh reports
  `Current leg to Kol` while retaining Brecconary. The loaded retest confirmed
  that status at frame `86255`. Its first `(104,44)->UP` activation exhausted
  two timing retries, but the unchanged same-origin retry crossed at frame
  `94321`, consistent with the known cave-exit timing seam rather than blocked
  geometry. Frame `96797` bypassed Kol at west doorstep `(103,10)`, frame
  `103421` handed off at bridge junction `(44,38)`, and frame `103725` entered
  Brecconary map `0x08`. Final frame `105780` confirmed `(0,15)`, path target
  nil, and zero runtime blockers; no route replacement after the fix, drift,
  cancellation, runtime-block injection, or script error occurred. Focused
  route tests pass `260/260`; Lua syntax, `git diff --check`, all 33
  host-runnable Lua suites, and all 68 Python tests pass.
- Swamp-Cave-North connections to Rainbow Bridge and Charlock are
  source-complete and live-verified (`2026-08-21`). Both reuse the one-step north
  re-entry pause, wait through the manual map `0x15` traversal without injecting
  movement, then hand off at World Map `(104,49)` to their unchanged final
  routes. New regressions cover both handoffs, their bounded first westbound
  segments, and an `R` guidance refresh at the physical south entrance. That
  refresh exposed a Charlock-only restaging bug: compatibility-only landmarks
  were accepted, but status recalculation could still select
  `swamp_cave_south`. Such landmarks now report the active route without
  recalculating from the incidental selection. Rainbow Bridge handed off at the
  south exit at frame `9083`, arrived at `(65,49)` at frame `13304`, and ended
  with route/path nil and zero runtime blockers at frame `13860`. Charlock
  handed off at frame `22331`; an `R` refresh at frame `25020` retained
  `charlock_castle`. Its first west step stopped once after two timing retries,
  then crossed from the same origin on the next activation at frame `30382`.
  The Rainbow run had already crossed that edge, so this was not promoted as
  geometry. Frame `34094` entered Charlock map `0x02`, and frame `34620`
  confirmed `(10,19)`, route/path nil, HP `149/149`, and zero runtime blockers.
  Neither run produced drift, cancellation, runtime-block injection, or a
  script error. Focused route tests pass `259/259`; Lua syntax and the full gate
  pass all 33 host-runnable Lua suites plus all 68 Python tests.
- Swamp-Cave-North to Magic Temple is source-complete and live-verified
  (`2026-08-21`). From World Map `(104,44)`, selecting Magic Temple
  now reuses the safe one-step north re-entry pause and waits through the manual
  map `0x15` crossing without injecting interior movement. Emerging at
  `(104,49)` activates the proven Rimuldar approach only through east doorstep
  `(103,72)`, bypassing town, then hands off to the unchanged Magic Temple
  corridor through `(108,109)` and destination map `0x0E`. Selection is limited
  to one tile around `(104,44)`, so starts at Swamp Cave south, Rimuldar, and
  Tantegel retain their established route choices. During the first live
  crossing, pressing `R` at the south exit replaced the itinerary because the
  physical cave object was selected. The two north-origin Rimuldar legs and the
  canonical south-exit temple staging leg now bind that object as compatible,
  preserving Magic Temple guidance even after a reload at `(104,49)`. The first
  run selected north staging at frame `6180`; its one-step move recovered from
  two bounded timing retries and completed at frame `6654`. Frame `8379` handed
  off inside map `0x15` without interior movement, frame `9719` resumed at the
  south exit, and pressing `R` exposed the replacement bug at frame `11761`.
  After the compatibility fix and reload, frame `3120` proved the same guidance
  refresh preserved the route, frame `7189` bypassed Rimuldar at east doorstep
  `(103,72)`, and frame `10053` reached Magic Temple's exterior stairs at
  `(108,109)`. STAIRS entered map `0x0E` at frame `13744`; final probe
  `MAGIC_TEMPLE_ARRIVAL_20260821` at frame `18180` confirmed `(0,4)`,
  route/path nil, HP `149/149`, and zero runtime blockers. The clean post-reload
  trip had no retry, blocker, drift, cancellation, runtime-block injection,
  unintended town entry, or script error. Focused route tests pass `257/257`;
  Lua syntax and the full gate pass all 33 host-runnable Lua suites plus all 68
  Python tests.
- Swamp-Cave-North to Rimuldar is source-complete and live-verified
  (`2026-08-21`). From World Map `(104,44)`, a Rimuldar selection now reuses the
  proven one-step north re-entry staging and waits through the manual map
  `0x15` crossing without injecting interior movement. Emerging at `(104,49)`
  advances the active route to the existing 11-step westbound `North Rimuldar
  west safer route`; all later waypoints and map `0x0B` arrival behavior are
  copied unchanged from the live-validated south-entrance route. Selection is
  limited to one tile around `(104,44)`, so the south cave entrance, Tantegel,
  and Magic Temple retain their established route variants. Focused route tests
  pass `253/253`; Lua syntax and the full gate pass all 33 host-runnable Lua
  suites plus all 68 Python tests. Loaded validation handed off into Swamp Cave
  map `0x15` at frame `5016`, resumed at south exit `(104,49)` at frame `8815`,
  and entered Rimuldar at frame `17670` after completing every remaining
  waypoint. Final probe `RIMULDAR_NORTH_ARRIVAL_20260821` at frame `22680`
  confirmed map `0x0B` position `(29,14)`, route/path nil, HP `149/149`, and
  zero runtime blockers. There was no timing retry, blocker, drift,
  cancellation, runtime-block injection, or script error. The final
  off-direction cleanup was the expected town map transition from `(103,72)`.
- Swamp-Cave-North to Swamp-Cave-South pilot is live-verified (`2026-08-21`).
  From clear World Map `(104,44)`, selecting
  `Swamp Cave South Entrance` now walks one safe `UP` step to `(104,43)` and
  pauses with instructions to step south, re-enter the automatic cave trigger,
  and cross manually. Entry into map `0x15` retains the selected destination
  without injecting cave movement; guidance completes only after the hero
  emerges on World Map `(104,49)`. The variant is origin-specific, so starts at
  `(104,49)` and Rimuldar `(102,72)` retain the canonical southern route.
  Focused route tests pass `250/250`; Lua syntax, `git diff --check`, all 33
  host-runnable Lua suites, and all 68 Python tests pass. Loaded validation
  selected the new staging leg at frame `6300`, paused at `(104,43)` at frame
  `6970`, and handed off on cave entry at frame `9472`. The player crossed the
  cave normally; frame `15791` recorded arrival on World Map `(104,49)`, and
  final probe `SWAMP_NS_ARRIVAL_20260821` at frame `17820` confirmed route/path
  nil, HP `149/149`, and zero runtime or NPC blockers. The initial north step
  recovered after two timing retries; no blocker, drift, cancellation,
  runtime-block injection, or script error occurred.
- Teleport transition safety guard is live-accepted (`2026-08-20`). A selected
  World Map teleport from `(29,57)` to
  Swamp Cave north `(104,44)` preceded a ROM lock with sustained audio while
  Lua continued polling. `$004E` remained aligned and finite, excluding the
  historical OAM lock. The first draft incorrectly treated `$003C/$003D ==
  0x7F/0x90` as an unsafe sentinel; a fresh stationary baseline at `(108,109)`
  and older successful teleport evidence proved those nonzero values can be
  normal. The corrected guard observes map position, scroll, player sprite,
  and movement-adjacent RAM each frame and requires the whole signature to be
  unchanged for six frames before any coordinate write. A refusal speaks the
  wait-and-retry message and logs stable/required frame counts plus the raw
  bytes. After a fresh system/emulator restart, a forced debug teleport from
  clear World Map `(108,109)` to the known-safe Swamp Cave north staging tile
  `(104,44)` passed the stability guard at frame `16320`. All twelve legacy
  post-teleport guard frames returned, the guard ended normally at frame
  `16331`, and a fresh probe at frame `16920` confirmed `(104,44)`, neutral
  input, finite/aligned `$004E`, no runtime blockers, and continued command
  polling. A later 12-frame raw UP hold changed the overworld movement shadow
  but did not complete a tile; do not treat that short hold as map evidence.
  Focused tests pass `4/4`; all 33 host-runnable Lua suites and all 68 Python
  tests pass. The user then confirmed normal movement and audio and exercised
  player-side selected teleport successfully. The same loaded run recorded
  successful selected teleports to Hauksness `(25,89)`, Mountain Cave
  `(29,57)`, and Charlock `(48,48)` twice, with normal trigger release and
  completed post-teleport guard frames. After the final Charlock teleport,
  manual movement completed `(48,48)->(48,49)`, castle entry and exit worked,
  and fresh frame `46080` confirmed World Map `(48,48)`, neutral input, no
  runtime blockers, finite/aligned `$004E`, and continued command polling.
  The interval contains no movement-stability refusal, OAM lock, or Lua error.
- Swamp-Cave-North connections to Cantlin and the Eastern Great Swamp Search
  Area are live-verified (`2026-08-20`). Both
  selections from World Map `(104,44)` now start with the proven one-step
  north departure on `kol_swamp_cave_staging`. Cantlin then composes
  `hauksness_swamp_cave_north_staging -> cantlin_swamp_cave_north`, handing
  off at Kol west doorstep `(103,10)` and Hauksness west doorstep `(24,89)`
  without entering either landmark. Great Swamp adds
  `cantlin_swamp_cave_north_staging -> great_swamp_swamp_cave_north`, handing
  off at Cantlin northwest turn `(68,91)` instead of entering town. The final
  legs reuse the existing live-validated Hauksness-to-Cantlin and
  Cantlin-to-Great-Swamp geometry. Selection is limited to four tiles around
  `(104,44)`; Kol `(104,10)`, Tantegel `(43,43)`, and Swamp Cave south
  `(104,49)` retain their prior choices. Cantlin handed off outside Kol at
  frame `27043`, outside Hauksness at frame `41715`, and entered map `0x0A`
  at frame `47283`. A timing-contaminated first departure recovered after a
  clean same-origin UP probe; the resumed route interval had no retry, blocker,
  drift, cancellation, runtime-block injection, or unintended map entry.
  Great Swamp handed off outside Kol at frame `63556`, outside Hauksness at
  frame `78228`, and northwest of Cantlin at frame `83236`, then arrived at
  `(89,112)` at frame `87028` without entering any intermediate map. Its full
  interval had no retry, blocker, drift, cancellation, runtime-block injection,
  map change, or Lua error. Final frame `88080` confirmed route/path nil, zero
  runtime or NPC blockers, neutral input, and finite/aligned `$004E`. Focused
  overworld-route tests pass `247/247`; Lua syntax and the full gate pass all
  33 host-runnable Lua suites plus all 68 Python tests.
- Swamp-Cave-North-to-Mountain-Cave connected route live-verified
  (`2026-08-20`). Selecting Mountain Cave at World Map `(104,44)` started
  `kol_swamp_cave_staging` with the intended one-step north departure. Frame
  `48191` handed off at Kol west doorstep `(103,10)` without entering town,
  frame `58959` handed off at western-desert pin `(18,64)`, and frame `59807`
  entered Mountain Cave map `0x16`. Final audit at frame `60240` confirmed
  `(0,7)`, route/path nil, and zero NPC or runtime blockers. No timing retry,
  failed or blocked step, drift, cancellation, runtime-block injection, or
  unintended map entry occurred. This completes live validation of the
  Swamp-Cave-North-origin Northern Cave, Hauksness, and Mountain Cave group.
- Swamp-Cave-North-to-Hauksness connected route live-verified (`2026-08-20`).
  Selecting Hauksness at World Map `(104,44)` started
  `kol_swamp_cave_staging` with the intended one-step north departure. Frame
  `20899` handed off at Kol west doorstep `(103,10)` without entering town,
  and frame `35619` entered Ruins of Hauksness map `0x03`. Final audit at frame
  `36120` confirmed `(0,10)`, route/path nil, and zero NPC or runtime blockers.
  No timing retry, failed or blocked step, drift, cancellation, runtime-block
  injection, or unintended map entry occurred. Mountain Cave is live-verified
  above.
- Swamp-Cave-North-to-Northern-Cave connected route live-verified
  (`2026-08-20`). Selecting Northern Cave at World Map `(104,44)` started
  `kol_swamp_cave_staging` with the intended one-step north departure. Frame
  `6317` handed off at Kol west doorstep `(103,10)` without entering town, and
  frame `9309` arrived at the Northern Cave exterior `(81,1)`. Final audit at
  frame `10920` confirmed World Map `(81,1)`, route/path nil, and zero NPC or
  runtime blockers. No timing retry, failed or blocked step, drift,
  cancellation, map change, or runtime-block injection occurred. Hauksness is
  live-verified above; Mountain Cave remains pending.
- Swamp-Cave-North northwestern connection batch is source-complete and partly
  live-verified (`2026-08-20`). Selecting Northern Cave, Hauksness, or
  Mountain Cave from World Map `(104,44)` now begins with the proven one-step
  north departure on `kol_swamp_cave_staging` and hands off at Kol west
  doorstep `(103,10)` without entering town. Northern Cave and Hauksness then
  reuse their established routes directly. Mountain Cave follows the existing
  Hauksness corridor to western-desert pin `(18,64)`, then hands off to the
  proven local cave spur. The origin-specific selection radius is four tiles,
  so Swamp Cave south `(104,49)` and other origins retain their prior route
  choices. Focused overworld-route tests pass `244/244`; the full gate passes
  all 33 host-runnable Lua suites plus 68 Python tests. Northern Cave is
  live-verified above, as are Hauksness and Mountain Cave. This batch is
  complete.
- Swamp-Cave-North-to-Garinham connected route live-verified (`2026-08-20`):
  selecting Garinham on World Map `(104,44)` composed
  `kol_swamp_cave_staging -> tantegel_bridge_swamp_cave_staging ->
  garinham_swamp_cave_north`. Frame `70930` handed off at Kol west doorstep
  `(103,10)` without entering town, frame `77554` handed off at bridge junction
  `(44,38)`, and frame `81026` entered Garinham map `0x09`. Final audit at
  frame `81300` confirmed `(0,14)`, route/path nil, and zero runtime blockers.
  No timing retry, failed or blocked step, drift, cancellation, runtime-block
  injection, or unintended map entry occurred. This completes live validation
  of the Swamp-Cave-North-origin Brecconary, Erdrick's Cave, and Garinham
  connection group.
- Swamp-Cave-North-to-Erdrick's-Cave connected route live-verified
  (`2026-08-20`): selecting the cave on World Map `(104,44)` composed
  `kol_swamp_cave_staging -> tantegel_bridge_swamp_cave_staging ->
  erdrick_swamp_cave_north`. Frame `33070` handed off at Kol west doorstep
  `(103,10)` without entering town, frame `39694` handed off at bridge junction
  `(44,38)`, and frame `41422` entered Erdrick's Cave B1 map `0x1C`. Final
  audit at frame `42840` confirmed `(0,0)`, route/path nil, and zero runtime or
  NPC blockers. No timing retry, failed or blocked step, drift, cancellation,
  runtime-block injection, or unintended map entry occurred. The parallel
  Garinham connection is live-verified above.
- Swamp-Cave-North-to-Brecconary connected route live-verified (`2026-08-20`):
  selecting Brecconary on World Map `(104,44)` composed
  `kol_swamp_cave_staging -> tantegel_bridge_swamp_cave_staging ->
  brecconary_swamp_cave_north` while preserving the town as the selected
  destination. Frame `6438` handed off at Kol west doorstep `(103,10)` without
  entering town, frame `13062` handed off at bridge junction `(44,38)`, and
  frame `13366` entered Brecconary map `0x08`. Final audit at frame `15180`
  confirmed `(0,15)`, route/path nil, and zero runtime blockers. No timing
  retry, failed or blocked step, drift, cancellation, runtime-block injection,
  or unintended map entry occurred. The parallel Erdrick's Cave connection is
  live-verified above; Garinham is also live-verified in the newest note.
  Focused tests pass `241/241` overworld routes; the full gate passes all 33
  host-runnable Lua suites plus 68 Python tests.
- Northern-Cave-to-Garinham connected route live-verified (`2026-08-20`):
  selecting Garinham on World Map `(81,1)` composed
  `kol_rain_shrine_staging -> tantegel_bridge_staging -> garinham_kol` while
  preserving the town as the selected destination. Frame `56749` handed off
  at Kol west doorstep `(103,10)` without entering town, frame `63373` handed
  off at bridge junction `(44,38)`, and frame `66845` entered Garinham map
  `0x09`. Final audit at frame `68400` confirmed `(0,14)`, route/path nil, and
  zero runtime blockers. No timing retry, failed or blocked step, drift,
  cancellation, runtime-block injection, or unintended map entry occurred.
  This completes live validation of the Northern-Cave-origin Brecconary,
  Erdrick's Cave, and Garinham connection group.
- Northern-Cave-to-Erdrick's-Cave connected route live-verified
  (`2026-08-20`): selecting the cave on World Map `(81,1)` composed
  `kol_rain_shrine_staging -> tantegel_bridge_staging -> erdrick_kol` while
  preserving the cave as the selected destination. Frame `28934` handed off
  at Kol west doorstep `(103,10)` without entering town, frame `35558` handed
  off at bridge junction `(44,38)`, and frame `37286` entered Erdrick's Cave
  B1 map `0x1C`. Final audit at frame `38220` confirmed `(0,0)`, route/path
  nil, and zero runtime blockers. Two entry retries on the first step from
  `(81,1)` recovered automatically. No failed or blocked step, drift,
  cancellation, runtime-block injection, or unintended map entry occurred.
  Garinham was the only parallel Northern-Cave-origin connection still awaiting
  live validation and is verified in the note above.
- Northern-Cave-to-Brecconary connected route live-verified (`2026-08-20`):
  selecting Brecconary on World Map `(81,1)` composed
  `kol_rain_shrine_staging -> tantegel_bridge_staging -> brecconary_kol` while
  preserving the town as the selected destination. Frame `6648` handed off at
  Kol west doorstep `(103,10)` without entering town, frame `13272` handed off
  at bridge junction `(44,38)`, and frame `13576` entered Brecconary map
  `0x08`. Final audit at frame `14700` confirmed `(0,15)`, route/path nil, and
  zero runtime blockers. No timing retry, failed or blocked step, drift,
  cancellation, runtime-block injection, or unintended map entry occurred.
  Parallel Erdrick's Cave and Garinham connections are also live-verified in
  the notes above. Focused tests pass `238/238` overworld routes and `123/123`
  route manager; the full gate passes all 33 host-runnable Lua suites plus 68
  Python tests.
- Kol-to-Brecconary connected route live-verified (`2026-08-18`): selecting
  Brecconary on World Map `(104,10)` chose `tantegel_bridge_staging`, bypassed
  Kol, and activated `brecconary_kol` at frame `91194` on the segment ending at
  bridge junction `(44,38)`. The short continuation entered Brecconary map
  `0x08` at frame `91498`. Final audit at frame `92760` confirmed `(0,15)`,
  route/path nil, and zero runtime blockers. No timing retry, failed or blocked
  step, drift, cancellation, runtime-block injection, or unintended map entry
  occurred. This completes live validation of the Kol-origin Garinham,
  Erdrick's Cave, and Brecconary connection group.
- Kol-to-Erdrick's-Cave connected route live-verified (`2026-08-18`):
  selecting the cave on World Map `(104,10)` chose
  `tantegel_bridge_staging`, bypassed Kol, and activated `erdrick_kol` at frame
  `73427` on the segment ending at bridge junction `(44,38)`. It entered
  Erdrick's Cave B1 map `0x1C` at frame `75155`. Final audit at frame `76620`
  confirmed `(0,0)`, route/path nil, and zero runtime blockers. No timing retry,
  failed or blocked step, drift, cancellation, runtime-block injection, or
  unintended map entry occurred. Brecconary was then the only Kol-origin
  connection still awaiting validation and is verified in the note above.
- Kol-to-Garinham connected route live-verified (`2026-08-18`): selecting
  Garinham on World Map `(104,10)` chose `tantegel_bridge_staging`, bypassed
  Kol, and activated `garinham_kol` at frame `14603` on the segment ending at
  bridge junction `(44,38)`. It then followed the established approach and
  entered Garinham map `0x09` at frame `18075`. Final audit at frame `19080`
  confirmed Garinham `(0,14)`, route/path nil, and zero runtime blockers. No
  timing retry, failed or blocked step, drift, cancellation, runtime-block
  injection, or unintended map entry occurred. The parallel Kol-origin
  Erdrick's Cave and Brecconary connections were implemented and static-tested
  at this point, then live-verified in the notes above. Focused tests pass
  `236/236` overworld routes and `123/123` route manager; the full gate passes
  all 33 host-runnable Lua suites plus 68 Python tests.
- Rimuldar intermediate-town bypasses live-verified (`2026-08-18`): connected
  routes in both directions now stop at east doorstep `(103,72)` and hand off
  on the World Map instead of stepping west into town. From Magic Temple,
  `rimuldar_magic_temple_staging` handed off to the south-cave return at frame
  `9887`; from approach waypoint `(88,58)`, `rimuldar_staging` handed off to
  `magic_temple` at frame `15485`. Neither run entered map `0x0B`, encountered
  a route failure, nor injected a runtime blocker. Direct Rimuldar travel still
  ends at town entrance `(102,72)`. Final audit at frame `16080` confirmed
  World Map `(110,80)`, path target nil, and zero runtime blockers. Focused
  tests pass `233/233` overworld routes and `123/123` route manager; the full
  gate passes all 33 host-runnable Lua suites plus 68 Python tests.
- Magic Temple-to-Tantegel connected return live-verified (`2026-08-17`):
  selecting Tantegel at World Map `(108,109)` now composes
  `rimuldar_magic_temple -> swamp_cave_south_magic_temple ->
  kol_swamp_cave_staging -> tantegel_kol`. Frame `5969` entered Rimuldar,
  frame `17805` entered Swamp Cave, frame `20976` returned from the north exit,
  frame `27311` bypassed Kol, and frame `34223` entered Tantegel Castle. The
  known cave-exit seam `(104,44)->UP` passed on the first activation. Final
  audit at frame `35880` confirmed Castle `(11,29)`, route/path nil, and zero
  runtime blockers. Focused tests pass `232/232` overworld routes and `123/123`
  route manager; the full gate passes all 33 host-runnable Lua suites plus 68
  Python tests. The later `2026-08-18` polish now bypasses Rimuldar during
  passing routes.
- Rainbow Bridge-to-Tantegel connected return live-verified (`2026-08-17`):
  selecting Tantegel at World Map `(65,49)` now composes
  `rainbow_bridge_return -> kol_swamp_cave_staging -> tantegel_kol`, preserving
  the final destination through automatic Swamp Cave entry and manual cave
  traversal. Frame `7037` handed off inside the cave, frame `11410` returned
  from the north exit, frame `20398` bypassed Kol, and frame `27310` entered
  Tantegel Castle. The known cave-exit seam `(104,44)->UP` exhausted one
  activation and passed unchanged on the next; it remains timing evidence, not
  geometry. Final audit at frame `27720` confirmed Castle `(11,29)`, route/path
  nil, and zero runtime blockers. Focused tests pass `231/231` overworld routes
  and `123/123` route manager; the full gate passes all 33 host-runnable Lua
  suites plus 68 Python tests.
- Charlock Castle-to-Tantegel connected return live-verified (`2026-08-17`):
  selecting Tantegel at World Map `(48,48)` now composes `charlock_return ->
  kol_swamp_cave_staging -> tantegel_kol`, preserving the final destination
  through automatic Swamp Cave entry and manual cave traversal. Frame `9225`
  handed off inside the cave, frame `12765` returned from the north exit,
  frame `24193` bypassed Kol, and frame `31105` entered Tantegel Castle. The
  first south step at Charlock recovered after two timing retries. The known
  cave-exit seam `(104,44)->UP` exhausted one activation and passed unchanged
  on the next; it remains timing evidence, not geometry. Final audit at frame
  `31500` confirmed Castle `(11,29)`, route/path nil, and zero runtime blockers.
  Focused tests pass `230/230` overworld routes and `123/123` route manager;
  the full gate passes all 33 host-runnable Lua suites plus 68 Python tests.
- Swamp Cave south-exit-to-Tantegel connected return live-verified
  (`2026-08-17`): selecting Tantegel while already on World Map `(104,49)` now
  keeps `swamp_cave_south` active instead of prematurely handing off and trying
  the invalid direct `(104,49)->UP` edge. The south entrance activates
  automatically when the hero steps onto its tile; when starting on the tile,
  step off and back on to enter. Frame `17087` handed off inside Swamp Cave to
  `kol_swamp_cave_staging`, frame `18518` returned from the north exit, frame
  `28989` bypassed Kol, and frame `35901` entered Tantegel Castle. Final audit
  at frame `36180` confirmed Castle `(11,29)`, route/path nil, and zero runtime
  blockers. Focused overworld-route tests pass `229/229`.
- Rimuldar-to-Tantegel connected return fully live-verified (`2026-08-16`):
  selecting Tantegel at World Map `(102,72)` composes `swamp_cave_south ->
  kol_swamp_cave_staging -> tantegel_kol`. The route preserves the final
  destination during manual Swamp Cave traversal and hands off outside Kol at
  west doorstep `(103,10)` without entering town. The initial run exposed that
  `kol_swamp_cave` retained the known blocked `(96,28)->UP` edge. It and its
  derived staging copy now use the live-proven `(96,32)`, `(98,32)`, `(98,26)`,
  `(96,21)` detour. The uninterrupted acceptance run completed both handoffs
  and entered Tantegel Castle `(11,29)`. A lag-related stall at the north cave
  exit `(104,44)->UP` exhausted one activation, then the identical edge passed
  on the next activation; do not promote it as geometry. One cave-interior
  retry also recovered. Keyboard-bridge heartbeat expirations increased near
  the end but caused no route drift or cancellation. Final state had route/path
  nil and zero runtime blockers. Focused tests pass `216/216` overworld routes
  and `123/123` route manager; the full gate passes all 33 host-runnable Lua
  suites plus 68 Python tests.
- Mountain Cave-to-Tantegel connected return live-verified (`2026-08-16`): a
  Tantegel request at World Map `(29,57)` now composes
  `mountain_cave_return -> kol_return_staging -> tantegel_kol` instead of using
  the generic north-ridge shortcut. The loaded continuous run exactly reversed
  the established cave spur to Western desert east road `(18,64)`, handed off
  outside Kol at west doorstep `(103,10)` without entering town, and entered
  Tantegel Castle map `0x04` at `(11,29)`. Final state had route/path nil and
  zero runtime blockers. The first west step used both configured timing
  retries and recovered; no later retry and no blocked, failed, canceled,
  drift, battle, or runtime-block event occurred. Focused tests pass `211/211`
  overworld routes and `123/123` route manager; Lua syntax, `git diff --check`,
  all 33 host-runnable Lua suites, and all 68 Python tests pass.
- Hauksness-to-Tantegel selection live-verified (`2026-08-16`): a Tantegel
  request at World Map `(25,89)` now selects the established Kol return
  itinerary through a Hauksness-only selection anchor, rather than the generic
  north-ridge shortcut. The normal distance guard still stages through
  `kol_return_staging`. The loaded continuous run handed off at Kol west
  doorstep `(103,10)` without entering town, then followed `tantegel_kol` into
  Tantegel Castle map `0x04` at `(11,29)`. Final state had route/path nil and
  zero runtime blockers. The log contains no blocked, failed, canceled, drift,
  battle, runtime-block, or nonzero-timeout event. Regression coverage also
  keeps the Mountain Cave `(29,57)` origin on its existing generic route.
  Focused tests pass `209/209` overworld routes and `123/123` route manager;
  Lua syntax, `git diff --check`, all 33 host-runnable Lua suites, and all 68
  Python tests pass.
- Great Swamp-to-Tantegel reverse backbone live-verified (`2026-08-16`): a
  Tantegel request at the Eastern Great Swamp Search Area safe pin `(89,112)`
  now composes `cantlin_return_staging -> hauksness_return_staging ->
  kol_return_staging -> tantegel_kol`. The internal routes reuse the established
  return geometry while stopping outside Cantlin at `(68,91)`, Hauksness at
  `(24,89)`, and Kol at `(103,10)`. A loaded continuous-autowalk run completed
  all three exterior handoffs without entering the intermediate town/ruins,
  then followed the established final leg into Tantegel Castle map `0x04`.
  The log contains exactly three handoffs and one final arrival, with no
  blocked, failed, canceled, drift, battle, runtime-block, or nonzero-timeout
  event. Final position was Tantegel Castle `(11,29)`, route/path nil, and zero
  runtime blockers. Focused tests pass `206/206` overworld routes and `123/123`
  route manager; Lua syntax, `git diff --check`, all 33 host-runnable Lua suites,
  and all 68 Python tests pass.
- Connected Rimuldar route fully live-verified (`2026-08-15`): a loaded request
  from World Map `(43,43)` composed `kol_staging -> swamp_cave -> rimuldar`
  rather than using the unvalidated 51-step direct segment. It handed off at
  Kol west `(103,10)` without entering town, then entered Swamp Cave map
  `0x15` at north interior `(0,0)` and activated the Rimuldar leg without
  moving the hero. The user autowalked a perfect cave route to south stair
  `(0,29)` and exited at World Map `(104,49)`. The preserved route resumed
  toward `(93,49)`, passed `(99,69)->south`, and entered Rimuldar map `0x0B`
  at `(29,14)`. Final tag `RIMULDAR_CONNECTED_ARRIVAL_20260815` confirmed route
  none, path nil, and zero runtime blockers. No blocker, cancellation,
  timing-retry, or exhausted-retry event occurred. Direct starts at `(104,49)`
  remain local. Focused tests pass `199/199`; the native Windows broad gate
  passes all 33 host-runnable Lua suites plus 68 Python tests. A complete user
  rerun also reached Rimuldar cleanly. The stale south-exit warning about live
  validation was replaced with `Poison swamp ahead after leaving the cave.
  Watch HP while crossing.` Regression coverage verifies the hazard warning and
  prevents the developer language from returning.
- Garinham and Erdrick's Cave Brecconary bypass live-verified (`2026-08-15`):
  both routes previously targeted Brecconary entrance `(48,41)` as their first
  intermediate waypoint from Tantegel. They now reuse the live-proven west
  bypass `(47,41)`, radius 0, then turn north to the unchanged bridge corridor
  at `(44,38)`. Direct Brecconary travel still ends at `(48,41)`, and the
  reverse Tantegel routes already avoided the town. Regressions cover both
  outbound routes, the northbound departure from the bypass, and the direct
  Brecconary control. Focused tests pass `194/194`; the native Windows broad
  gate passes all 33 host-runnable Lua suites plus 68 Python tests. Separate
  clean loaded runs from World Map `(43,43)` both completed the bypass and
  turned north through `(44,38)` without entering map `0x08`. Garinham arrived
  on map `0x09` at `(0,14)`; Erdrick's Cave arrived on map `0x1C` at `(0,0)`.
  Both final probes reported route/path nil and zero runtime blockers, with no
  blocker, cancellation, or exhausted-retry event in either run.
- Kol and Cantlin/Hauksness intermediate-town bypasses live-verified
  (`2026-08-15`): direct
  Kol travel now uses the live-proven Brecconary west doorstep `(47,41)` and
  turns north toward `(44,38)` instead of stepping east onto town entrance
  `(48,41)`. Connected routes use a hidden `kol_staging` copy that retains the
  same corridor but ends at Kol west doorstep `(103,10)`, handing off to the
  requested Northern Cave, Swamp Cave, Hauksness/Cantlin, or Mountain Cave leg
  without entering Kol `(104,10)`. Direct Kol selection still enters Kol, and
  accidental Kol entry still performs the staged handoff. A clean continuous
  Hauksness run from World Map `(43,43)` passed Brecconary at `(47,41)` without
  entering map `0x08`, reached `(103,10)`, handed off from `kol_staging` to
  `hauksness`, and turned west without entering Kol map `0x07`. It then
  completed the established route and entered Ruins of Hauksness map `0x03`
  from `(24,89)`. Fresh tag `KOL_HAUKSNESS_POLISH_FINAL_20260815` confirmed
  Hauksness `(0,10)`, route none, path nil, and zero NPC/runtime blockers.
  The user's following Cantlin run then exposed that the intermediate
  `hauksness` leg still entered map `0x03` before handing off. Cantlin staging
  now uses a hidden `hauksness_staging` copy that stops at exterior `(24,89)`;
  it hands off directly to the westbound Cantlin route at `(22,89)`. Direct
  Hauksness travel still enters the ruins, and accidental Hauksness entry
  remains a fallback handoff. Focused route tests pass `191/191`; the native
  Windows broad gate passes all 33 host-runnable Lua suites plus 68 Python
  tests. The loaded follow-up reached World Map `(24,89)` at frame `15739`,
  handed off from `hauksness_staging` without a map change, and immediately
  routed left toward `(22,89)`. It reached `(22,89)` at frame `15836` and
  continued normally toward Cantlin without entering the ruins. The route
  entered Cantlin map `0x0A` at `(15,0)`; fresh tag
  `CANTLIN_TOWN_BYPASS_FINAL_20260815` confirmed route none, path nil, and no
  runtime blockers.
- Connected Eastern Great Swamp route and Cantlin bypass live-verified
  (`2026-08-16`): far search-area travel now composes `kol_staging ->
  hauksness_staging -> cantlin_staging -> great_swamp_cantlin`. The initial
  loaded run completed the full itinerary to safe search-area pin `(89,112)`.
  Passing routes now stop the shared Cantlin approach at northwest turn
  `(68,91)` and hand directly to south notch `(68,92)`, avoiding town map
  `0x0A` and eliminating the old descent/exit interruption. Direct Cantlin
  travel still enters town, and accidental entry still performs the staged
  handoff. A focused loaded rerun from Hauksness west doorstep `(24,89)`
  completed the exterior handoff and continued normally into the Great Swamp
  route with no retry, drift, blocker, cancellation, or map change. Final tag
  `CANTLIN_BYPASS_FINAL_20260816` confirmed route/path nil and zero runtime
  blockers after the deliberate stop. Focused tests pass `203/203`; the full
  33-Lua-suite and 68-Python-test gate passes.
- Connected Mountain Cave route fully live-verified (`2026-08-15`): selecting
  Mountain Cave outside Kol now stages through an internal connector ending at the
  live-validated `Western desert east road` pin `(18,64)`, then hands off to
  the existing short cave spur. The connector is derived from the established
  Hauksness waypoint prefix rather than duplicating its turns or timing
  metadata. Selecting Mountain Cave from Tantegel `(43,43)` composes
  `kol -> mountain_cave_connector -> mountain_cave`; starts at `(18,64)` or on
  the local cave corridor remain direct. Both handoffs preserve Mountain Cave
  as the selected Travel object. With continuous overworld walking enabled,
  the loaded route handed off at `(18,64)` and continued onto the local spur
  without another activation.
  Focused route tests pass `189/189`; the native Windows broad gate passes all
  33 host-runnable Lua suites plus 68 Python tests. The clean loaded pass began
  on World Map `(104,10)`, entered Mountain Cave map `0x16` at `(0,7)`, and
  ended with route/path state clear and zero NPC/runtime blockers. The user then
  manually repeated and accepted the same route; fresh tag
  `MCAVE_MANUAL_ACCEPTANCE_20260815` confirmed the same clean final state. A
  complete manual run from Tantegel `(43,43)` then composed `kol ->
  mountain_cave_connector -> mountain_cave`, entered Brecconary and Kol as
  expected for the legacy early route, completed both handoffs, and arrived in
  Mountain Cave. The log contained one recovered timeout retry at `(43,43) ->
  UP`, with no blocker, cancellation, or exhausted retry. Early-route town
  entry remains separate polish; this connected-route slice is accepted.
- Connected Cantlin route live-verified (`2026-08-15`): selecting Cantlin from
  Tantegel World Map `(43,43)` now composes the existing `kol`, `hauksness`,
  and `cantlin_hauksness` routes instead of synthesizing the prior 62-step
  shortcut. The route state holds an ordered continuation list, keeps the
  Cantlin Travel object bound during both staging legs, names the current leg
  and final destination, and pauses without injecting movement at the Kol and
  Hauksness handoffs. Direct starts at Hauksness `(25,89)` and the Eastern
  Great Swamp Search Area `(89,112)` remain on their local live-validated
  Cantlin routes. Regressions cover alias and Travel-object starts, waypoint
  and town-entry handoffs, guidance refresh, final-object binding, and cancel
  cleanup. Live acceptance from `(43,43)` completed all three legs. The Kol
  handoff activated `hauksness`; the Hauksness handoff activated
  `cantlin_hauksness`; and the final leg entered Cantlin at `(15,0)`. Each
  handoff paused for the manual town exit as designed. No blocked, canceled,
  or retry-exhausted event occurred, and the final probe reported route none,
  path target nil, and zero runtime blockers. The known Brecconary and Kol
  entries remain separate early-route polish. Focused tests pass `184/184`;
  the native Windows broad gate passes all 33 host-runnable Lua suites plus 68
  Python tests.
- Connected Hauksness route (`2026-08-14`): selecting Hauksness at
  Tantegel World Map `(43,43)` now stages through `kol`, keeps the Hauksness
  Travel target bound during the first leg, and hands off at Kol `(104,10)` to
  the established westbound Hauksness route without injecting movement during
  the handoff. A regression first reproduced the old direct 30-north shortcut;
  the Hauksness-specific staging guard now passes while an on-route Garinham
  start remains direct. The existing waypoints and final transition at
  `(25,89)` are unchanged. Continuous overworld auto-walk is integrated and
  exposed in `dw_access.ini` as `overworld_auto_walk_continuous`; waypoint mode
  remains the shipped default (`false`). When enabled, routine internal waypoint
  speech and per-segment progress are suppressed while warnings and final
  arrival remain.
  Focused tests pass `179/179` overworld routes, `123/123` route manager, and
  `3/3` config tests; the full repository gate passes all 33 host-runnable Lua
  suites plus 68 Python tests. Loaded validation with continuous mode enabled
  from `(43,43)` started `kol`
  with `staged_from=hauksness`, preserved the final destination, and handed off
  to `hauksness` on entering Kol map `0x07`. The Kol leg exposed the known
  intermediate Brecconary entry and one automatically recovered timing retry.
  After the manual town exits, continuous Hauksness travel completed every
  remaining waypoint with no timeout, blocker, or cancellation events and
  entered map `0x03` from `(24,89)`. Fresh tag
  `HAUKSNESS_ARRIVAL_20260814` confirmed Ruins of Hauksness `(0,10)`, route
  none, path nil, and zero NPC/runtime blockers. This slice is live-verified;
  early-route town entry remains separate polish.
- Connected Magic Temple route (`2026-08-14`): selecting Magic Temple at
  Swamp Cave South `(104,49)` now stages through the established `rimuldar`
  leg, retains Magic Temple as the final destination, and hands off on entering
  Rimuldar map `0x0B` at `(29,14)` without starting movement. After the player
  manually exited to World Map `(102,72)`, the preserved `magic_temple` leg
  completed all 22 waypoints and arrived at `(108,109)`. Fresh tag
  `MAGIC_TEMPLE_CONNECTED_ARRIVAL_20260814` confirmed route none, path nil,
  and zero NPC/runtime blockers. Manual acceptance reproduced a legitimate
  engine block at `(93,52)->DOWN`. The outbound route now turns west through
  the proven reverse corridor at `(92,52)`, `(86,52)`, `(86,54)`, `(83,54)`,
  `(83,56)`, `(85,56)`, `(85,58)`, and `(88,58)`. After reload, every new
  waypoint completed normally and the route rejoined its original corridor at
  `(88,71)` without a blocked, canceled, seam-retry, or runtime-block event;
  fresh tag `MAGIC_TEMPLE_RIMULDAR_DETOUR_LOADED_20260814` confirmed the clean
  reconnect. On the temple leg, `(110,86)->LEFT` and
  `(102,107)->LEFT` passed normally; `(103,113)->RIGHT` failed queued timing
  but passed a same-origin raw hold, and `(104,113)->DOWN` completed on its
  second bounded retry. No blocker or unrelated route data was added. Focused
  route tests pass `175/175`; the broad gate passes all 33 host-runnable Lua
  suites plus 68 Python tests. Final manual acceptance completed the connected
  itinerary at `(108,109)`. Two visible Rimuldar timing stalls at
  `(97,71)->UP` and `(107,71)->DOWN`, plus two temple stalls at
  `(103,113)->RIGHT` and `(104,113)->DOWN`, each completed on the next route
  activation. Fresh tag `MAGIC_TEMPLE_MANUAL_ACCEPTED_20260814` confirmed
  route none, path nil, and zero NPC/runtime blockers.
- Connected Charlock route (`2026-08-13`): selecting Charlock outside Rimuldar
  at `(102,72)` now follows `swamp_cave_south`, enters Swamp Cave south at
  `(0,29)`, waits for the player to exit with STAIRS, preserves Charlock across
  that transition, and continues from World Map `(104,49)` to the castle.
  Complete loaded acceptance traversed every waypoint and entered Charlock map
  `0x02` at `(10,19)`. The final probe found route none, path nil, and zero
  NPC/runtime blockers. Three recoverable timing artifacts occurred across the
  full itinerary: `(99,69)->LEFT` and `(51,64)->RIGHT` exhausted auto-step
  retries but passed unchanged-origin raw holds, while `(90,72)->UP` carried to
  `(90,70)` and rejoined normally. The known slow edges `(58,55)->LEFT` and
  `(50,61)->LEFT` passed in 30 and 28 frames with zero retries. No blocker was
  added; the artifacts remain optional future route polish. The user's final
  manual pass also completed the entire itinerary. Its log contained several
  bounded timing retries and harmless carries, but no `event=blocked` or
  `event=cancel`; every segment completed, the cave handoff remained intact,
  and frame `21326` arrived in Charlock. Fresh tag
  `CHARLOCK_MANUAL_ACCEPTED_20260813` confirmed map `0x02` `(10,19)`, route
  none, path nil, and zero NPC/runtime blockers.
- Connected Rainbow Bridge route (`2026-08-13`): a Rainbow Bridge selection
  from the Rimuldar side now follows `swamp_cave_south`, hands off on entering
  Swamp Cave south at `(0,29)`, waits for STAIRS, and continues from World Map
  `(104,49)` to the unlock point. Live testing corrected the Rimuldar direct
  north carry, four diagonal-turn drift points, and the blocked
  `(98,70)->DOWN` wall approach; the valid bypass moves LEFT to `(97,70)`
  before moving DOWN. The reloaded itinerary completed every staging and
  bridge waypoint and arrived at `(65,49)`. Final state had no active route,
  path, or runtime blockers. Manual acceptance later exposed a slow passable
  edge from `(99,68)` DOWN to `(99,69)`. After giving that waypoint the same
  sustained-hold timing used by other slow overworld seams, loaded auto-walk
  completed it in 33 frames with zero retries and advanced toward `(98,69)`;
  no blocker was added. The user's final manual round trip reached Rainbow
  Bridge `(65,49)` and returned through Swamp Cave to World Map `(104,49)`.
  Two timing stalls succeeded on retry, while recoverable carries reached
  `(90,70)` and overshot the final bridge stand to `(64,49)`. These are
  non-destructive future-polish items; no runtime blocker was inserted. Fresh
  final state had route none, path nil, and zero runtime/NPC blockers. Focused
  route tests pass `169/169`; the broad gate passes all 33 host-runnable Lua
  suites plus 68 Python tests.
- Native opened-chest tracking (`2026-08-10`): a fresh Dragonlord treasure-room
  raid opened all six chests, but the successful Herb pickup at `(13,13)` did
  not remain labeled opened even though the two Herb chests raised the count
  from `2` to `4`. The game itself records up to eight taken chest coordinates
  at `$601C-$602B` before awarding contents. ROM chests now use that array as
  authoritative state, while hidden SEARCH treasures retain their separate
  fallback cache. The regression failed first and then passed `114/114` object
  tests plus the broad repository gate. After manual Lua reload, fresh marker
  `chest_ram_reload` was consumed at map `0x06` `(13,13)` and a complete
  nine-object cycle logged all six room coordinates as `Chest (opened)`.
- Full-game ending and credits (`2026-08-09`): after returning to Tantegel and
  completing King Lorik's ending sequence, every story page and the complete
  staff credits were automatically narrated by the existing dialogue detector.
  The final image is the original `The End` screen. A fresh probe found the
  ROM's terminal state: level byte `255`, non-gameplay/title classification,
  Tantegel's last coordinates `(10,8)` retained only as stale RAM, no active
  menu/dialogue or mod input guard, and a healthy speech bridge. An A-button
  state occurred while this screen remained unchanged, confirming an intended
  ROM ending loop rather than an accessibility control lock. Minor polish
  remains: suppress the premature `Title screen.` announcement and two
  decorative-glyph fragments spoken after the legitimate copyright credits.
- Dragonlord victory announcement (`2026-08-09`): after the final battle, the
  game displayed `Thou hast done well in defeating the Dragonlord.`, but JAWS
  announced nothing. The filtered and announced caches contained the complete
  text, the speech backend remained healthy, and `speech_bridge.log` proved the
  line was sent as non-interrupting `speak:` output after a speech-heavy fight.
  Terminal Dragonlord victory text now uses interrupting speech so it cannot
  remain behind the combat backlog or be discarded by a later interrupt.
  Ordinary enemy victories retain queued speech. The new focused regression
  failed before the helper existed and now passes with all `44/44` battle and
  `74/74` text tests plus Lua syntax. After manual reload on the victory page,
  `speech_bridge.log` recorded the line as `interrupt:` and JAWS read it
  successfully. JAWS then read the Ball of Light and both world-restoration
  pages without omissions. The game moved to World Map `(48,48)`; a fresh
  probe found full HP/MP, no active menu/dialogue/input guard, and a healthy
  JAWS bridge. This fix is live-verified end to end.
- Dragonlord YES ending (`2026-08-09`): the complete alternate-ending dialogue
  was spoken page by page at lair `(17,24)`. The final screen was read as
  `Thy journey is over. Take now a long, long rest. Hahahaha....` with no
  missing rows or repetition corruption. A fresh snapshot confirmed the
  intentional terminal state: field mode remains on map `0x06`, the raw menu
  stays asserted, movement remains blocked, and gold, experience, keys, herbs,
  inventory/progress bytes, and quest flags are cleared. The final 96-character
  dialogue matched both the filtered and announced caches. Restore the
  pre-dialogue save state or reset after this branch; answer NO to start the
  actual Dragonlord battle.
- Battle spell-name filtering (`2026-08-09`): a live Wizard cast displayed
  `HURTMORE.` on its own PPU row, but the accessibility dialogue filter dropped
  that all-uppercase row and announced `chants the spell of But that spell hath
  been blocked.` The original game was not hiding the spell. `text.lua` now
  preserves an uppercase row only when it follows `chants the spell of`, so
  unrelated menu/status debris remains filtered. The regression failed with
  the captured sentence before the fix and passed afterward (`74/74` text
  tests). After manual reload, a Starwyvern cast logged and spoke the complete
  `Starwyvern chants the spell of HEALMORE.`, followed separately by its
  recovery message, completing live validation.
- Charlock remaining B1/B2 connectors (`2026-08-09`): live movement and STAIRS
  proved the four optional pairs B1 `(14,9)` / B2 `(8,9)`, B1 `(19,7)` / B2
  `(9,8)`, B1 `(2,14)` / B2 `(0,1)`, and B1 `(2,4)` / B2 `(0,0)`. The direct
  north step from B2 `(0,1)` onto `(0,0)` worked; the hypothesized `(1,0)`
  detour was not needed. Source exposes all eight Travel endpoints and models
  only boundary passthroughs `(0,0)` and `(0,1)`. Focused verification passes
  `113/113` object tests, `81/81` map-reader tests, Lua syntax, and
  `git diff --check`. After restart/reload, exact loaded lookups found all four
  B1 and all four B2 stair names. B1 `(2,4)` then descended to B2 `(0,0)`,
  where both boundary cells reported `reason=passthrough`; runtime/NPC blocks,
  path state, and input guard were clean. The visible ground-floor decoys and
  remaining B1/B2 optional stair graph are complete.
- Charlock false branch and loop (`2026-08-06`): B4 stair `(8,1)` entered B5
  `(4,0)`. Clean movement crossed hidden top-boundary cells `(5,0)..(7,0)`,
  then followed the inner corridor `7 south, 5 west, 5 north, 3 east, 3 south`
  to B5 descent `(5,5)`. That stair entered B6 `(0,0)`. Same-origin movement
  crossed the complete hidden top row to `(9,0)`, and STAIRS there returned to
  B6 `(0,0)`, proving the deliberate same-floor loop. Two apparent B6
  `(3,0)->(4,0)` blocks occurred while controls were locked; after Start
  restored control, the edge and the remainder of the row moved cleanly.
  Source adds only the fourteen proven boundary cells; verification passes
  `79/79` map-reader and `109/109` object tests, Lua syntax, and
  `git diff --check`. After reloading, the source-only B6 planner produced
  exactly `9 east` from `(0,0)` and autowalk completed at `(9,0)` with no
  runtime blockers. STAIRS then returned to B6 `(0,0)`, validating the loaded
  same-floor loop end to end.
- Charlock Erdrick's Sword branch (`2026-08-06`): from B4 `(7,7)`, the live
  route ascended through B3 `(7,7)->(2,2)`, crossed the adjacent B2 stair pair
  `(9,1)->(9,0)->(8,0)`, and entered B1 `(15,1)`. The missed onward turn is
  LEFT from `(19,2)` after following the top boundary `(15,0)..(19,0)`; the
  southwest zigzag ends at B1 stair `(13,7)`, which enters the isolated B2
  sword room at `(4,4)`. TAKE on chest `(5,5)` produced the Erdrick's Sword
  dialogue, changed equipment byte `$00BE` to `0xFF`, and raised Attack from
  115 to 127. The complete reverse route returned to B4 `(7,7)`. Source now
  models only the seven newly proven boundary cells, and `79/79` focused
  map-reader tests, Lua syntax, and `git diff --check` pass. The loaded forward
  and reverse routes were subsequently validated without runtime blockers.
- Complete Charlock dungeon (`2026-08-06`): the full intended spine is now
  live-proven from ground-floor entrance `(10,19)` through the hidden SEARCH
  stair `(10,1)`, B1 `(9,0)->(8,19)`, B2 `(5,0)->(3,0)`, the direct B3 route
  `(7,0)->(1,6)`, B4 `(0,9)->(2,2)`, B5 perimeter
  `(9,0)->(0,0)`, B6 lower route `(0,6)->(9,6)`, and Dragonlord's Lair entry
  `(10,29)` to boss approach `(17,24)`. The final floor needs four
  coordinate-scoped raw-type-0 passages at `(28,13)`, `(28,14)`, `(25,16)`,
  and `(25,21)`; the loaded source route crossed them and completed without
  runtime blocks. TALK at `(17,24)` produced Dragonlord's opening dialogue,
  and reloaded object browsing identifies the stationary NPC at `(16,24)` as
  `Dragonlord`. Verification passes `79/79` map-reader and `109/109` object
  tests, Lua syntax, and `git diff --check`. A later loaded topology audit again
  completed the full main spine to lair entry `(10,29)` with no runtime
  blockers. It proved that B3's false stair loop is optional, all three tested
  B4 branch stairs share one walking component, and the B5/B6 false-loop
  components are disconnected from their respective main-route arrivals. The
  reverse stair then moved from lair `(10,29)` to B6 `(9,6)`. Because that
  live-proven return stair was missing from Travel navigation, map `0x06` now
  exposes `South Stairs Up` at `(10,29)`; all 110 object tests pass. After
  reload and re-entry, Travel reported `South Stairs Up: here (1 of 1)` at
  `(10,29)`, completing live verification. A follow-up door audit disproved the
  generic raw-type-5 `Door` at that same stair and confirmed the actual locked
  treasure-room door at `(17,12)`: OPEN from east stand `(18,12)` facing west
  consumed one key and wrote opened-door RAM `(17,12)`. Source now exposes the
  named `Treasure Room Door` with east and west interaction stands, and treats
  `(17,12)` as planner-passable only while its door RAM slot is open. Verification
  passes `80/80` map-reader and `112/112` object tests, Lua syntax, and
  `git diff --check`. Loaded inspection reported `reason=door_open`, and normal
  movement crossed the door in both directions. All six room chests were
  reached: `(11,11)` Herb, `(11,12)` 680 gold, `(12,12)` Magic Key, `(11,13)`
  Wings, `(12,13)` Cursed Belt, and `(13,13)` Herb. TAKE at `(13,13)` while
  carrying six Herbs consumed the chest but discarded its reward, reporting
  `Unfortunately, it is empty.` Native taken-treasure RAM now marks that case
  opened without relying on dialogue or an inventory increase, and the state
  survives Lua reloads. The ordinary return route then
  crossed the open door eastward and continued from `(18,12)` to lair stair
  `(10,29)`. Two Armored Knights and one Red Dragon interrupted combat, but
  each resumed segment remained source-only and the final state had no runtime
  blockers or active path.
- Charlock B3 main route (`2026-08-05`): STAIRS at B2 `(3,0)` entered B3
  `(7,0)`. The first right-edge/lower route reached false return stair `(0,9)`,
  which crossed B2 `(1,9)->(0,9)->(0,8)` and re-entered B3 at `(5,4)`. From
  there, live movement decoded the central alcove and connected north through
  `(6,4)->(6,3)->(6,2)`, west to `(4,2)`, north to `(4,0)`, west across the
  hidden top boundary, and south through `(0,0)..(0,6)` to the real B4 descent
  `(1,6)`. Clean probes establish type-0/type-8 walls and real separators
  `(6,0)` and `(0,7)`. Source now models all proven boundary cells and all six
  ROM-backed B3 stairs. Verification passes `75/75` map-reader and `108/108`
  object tests, Lua syntax, and `git diff --check`. Reload at B3 `(1,6)`, then
  verify the loaded stair object and descend to expected B4 `(0,9)`.
- Charlock B1/B2 main route (`2026-08-04`): B1's hidden perimeter corridor is
  live-proven from return stair `(9,0)` to main descent `(8,19)`, including the
  real separator at `(0,7)`. STAIRS entered B2 map `0x10` at `(5,0)`. The B2
  route crossed the eastern and lower maze, followed the live-passable west
  edge `(0,6)..(0,3)`, and reached the real B3 descent `(3,0)`. Repeated clean
  probes establish type-0 and type-8 as B2 walls, while the stair types and
  live boundary route are now modeled. Stale B2 stair objects `(7,7)` and
  `(3,3)` are replaced by main stairs `(5,0)` up and `(3,0)` down. Focused
  verification passes `74/74` map-reader and `108/108` object tests. Reload at
  B2 `(3,0)` before the final loaded-model and STAIRS transition check.
- Charlock ground floor (`2026-08-04`): map `0x02` is decoded and live-proven.
  The corrected planner follows the intended western route from entrance
  `(10,19)` to throne `(10,3)` instead of crossing type-4 stone walls. SEARCH
  at the throne gives the wind clue; the direct north wall at `(10,2)` remains
  correctly blocked, and the route goes around to hidden coordinate `(10,1)`.
  SEARCH there reveals the Secret Passage, and STAIRS enters Dragonlord B1 map
  `0x0F` at `(9,0)`. Loaded ordinary autowalk later reached `(10,1)` from
  `(9,1)` with no runtime blocks. B1 return STAIRS is `(9,0)`; the previous
  `(10,1)` object coordinate said no stairs and is corrected in source.
  Verification passes 74 map-reader and 108 object tests, Lua syntax, and
  `git diff --check`.
- Charlock Castle route (`2026-08-03`): live probing crossed the formed
  Rainbow Bridge and established the island corridor from `(63,49)` through
  its south road at `(56,64)` and west rise at `(49,57)` to the castle.
  Stepping onto World Map `(48,48)` entered Charlock Castle map `0x02` at
  `(10,19)`; leaving south returned to `(48,48)`. New strict outbound and
  return routes connect the Swamp Cave south doorstep `(103,49)` with the
  castle, including the already proven bridge-inlet detour. No runtime or
  permanent blockers were added. Loaded `charlock_return` completed into Swamp
  Cave, and loaded `charlock_castle` completed from `(103,49)` into Charlock at
  `(10,19)` with arrival and route/path cleanup. Two outbound west steps,
  `(58,55)->(57,55)` and `(50,61)->(49,61)`, exhausted cadence retries but
  passed clean same-origin raw holds; their waypoints now use the established
  60-frame sustained-hold window and await a focused post-reload check.
  Follow-up route-start review found that selecting Charlock from Rimuldar
  `(102,72)` could synthesize a direct northbound segment to the validated
  doorstep. The route now stages through the established `swamp_cave_south`
  chain unless already on the validated Charlock corridor, preserves that
  staging across Travel refresh/recalculation, and uses the westbound recovery
  at the blocked `(92,57)->UP` notch.
- Rainbow Bridge route (`2026-08-03`): Travel now exposes the Rainbow Bridge
  unlock point at `(65,49)`. The recommended staging point is Swamp Cave South
  Entrance `(104,49)`, following the north road west and detouring around the
  water inlet through `(70,50)` and `(67,50)`. Using the Rainbow Drop set the
  bridge-state bit, and ordinary movement crossed bridge tile `(64,49)` from
  both shores. The complete eastbound return entered Swamp Cave map `0x15` at
  `(0,29)`, announced route arrival, and cleared guidance with no runtime
  blockers. One cave-entry run needed the route executor's two bounded timing
  retries; it recovered without player intervention or map-data changes.
  Follow-up route-start review applies the same staging guard as Charlock:
  Rimuldar and other off-corridor starts use `swamp_cave_south`, while the
  validated row-49/50 bridge corridor remains directly selectable.
- Explorer installer/launcher regression (`2026-07-31`): manual download,
  extraction to `C:\tmp1\Dragon Warrior Accessibility 0.1.0-alpha`, and
  double-click of `Install Dragon Warrior.cmd` failed before setup with
  `GetFullPath` reporting `Illegal characters in path.` The batch wrappers were
  passing quoted `%~dp0`, whose required trailing backslash can escape the
  native closing quote. Install and Play now pass `%~dp0.`; `GetFullPath`
  normalizes the dot while preserving the complete path. Regression tests now
  execute both real `.cmd` entry points through `cmd.exe` from a package folder
  containing spaces. The two new tests fail with the published wrappers, pass
  with the fix, and the full installer/launcher/package suite passes 31 tests.
  Two PowerShell 7 package builds match at SHA-256
  `C3877D93EE8A66FE3C04563FB8CB7A146F07795B5D653FB719330112A1D240B7`.
  A real rebuilt root installer then passed through `cmd.exe` under `C:\tmp1`,
  copied the supported ROM with its expected hash, and exited 0 without the
  illegal-path error. The user independently extracted the candidate under
  `C:\tmp2`, completed setup from Windows Explorer, launched the emulator, and
  confirmed the ROM and script loaded. Package evidence matched the candidate
  wrappers/runtime, selected JAWS, reached speech `READY`, narrated the title,
  and produced no script-error file. PR #9 merged as `133d65c`; the existing
  `v0.1.0-alpha` prerelease tag, player ZIP, checksum, and notes were updated.
- Final `0.1.0-alpha` package acceptance (`2026-07-31`): separate clean JAWS
  and NVDA extractions installed the verified US Rev 1 ROM with no inherited
  saves. Each run had only the intended screen reader active, selected the
  correct backend, reached speech `READY`, narrated startup, and passed hero
  creation, king dialogue, keyboard input, controller input, object navigation,
  autowalk, and FCEUX menu pause/resume. After normal emulator exit, each
  private package contained an 8,192-byte battery save plus the user's manual
  `dw_release_test.sav`; relaunch exposed Continue a Quest and restored the
  expected hero (JAWS slot 1, NVDA slot 2) with speech and controls working.
  The first JAWS selected teleport temporarily stopped ordinary controls until
  Start was pressed; remaining teleport tests worked. The player README and
  keyboard guide now document Start, script reload, and close-without-saving
  relaunch as alpha recovery. Investigate the underlying teleport/input seam
  after release. The documentation-final player build is reproducible under
  PowerShell 7 at 516 payload entries, 47,471,642 ZIP bytes, and SHA-256
  `C3877D93EE8A66FE3C04563FB8CB7A146F07795B5D653FB719330112A1D240B7`
  after the Explorer-wrapper hotfix.
- Release-document checkpoint (`2026-07-31`): PR #7 added the player README at
  commit `82ffbad`. The release branch corrects its unsupported-ROM opt-in,
  NVDA/JAWS/SAPI5 backend wording, teleport state/save-risk warning, JoyToKey
  packaging scope, separate keyboard-guide pointer, and stock FCEUX startup
  limitation. The standalone keyboard guide ships teleport enabled with exact
  controls and warns that misuse can corrupt later gameplay or save data while
  leaving the original ROM untouched. Ten documentation tests, 37 other release
  tests, and `git diff --check` pass.
- Internal licensed release-runtime checkpoint (`2026-07-31`, superseded by
  final acceptance above): the player package now
  carries real project and third-party notices plus a same-version FCEUX/Qt/NVDA
  corresponding-source process. Eight unused FFmpeg DLLs were removed; ANGLE
  and Mesa `opengl32sw.dll` remain as documented graphics fallbacks. Speech now
  packages only the official pinned 64-bit NVDA Controller Client, selects
  active NVDA explicitly, then installed JAWS, then SAPI5, and has six focused
  backend-selection tests. Two deterministic licensed builds contained 689
  payload files, no ROM/save data or FFmpeg files, and produced the same
  SHA-256. The 47,777,459-byte ZIP is 58,279,624 bytes smaller than the earlier
  internal ZIP. The full local smoke suite, 37 release unit tests, and
  `git diff --check` pass. The requested separate final packaged NVDA and JAWS
  smoke passes are now complete.
- Non-ASCII player-package acceptance (`2026-07-31`): the untouched rebuilt
  ROM-free ZIP was extracted to
  `C:\tmp\DWA Rebuilt 20260731 – naïve тест 日本語`, then setup installed the
  verified US Rev 1 ROM. First launch and repeat launch produced responsive
  qfceux PIDs 38776 then 27476, selected `NVDA reason=auto`, reached speech
  status `READY`, narrated the title, retained ASCII 8.3 aliases in
  `SDL.LuaScript` and `SDL.LastLoadLua`, and kept an advancing package keyboard
  heartbeat. The user manually confirmed object navigation, Enter opening the
  title menu, `F` opening New Quest, and a quick post-restart key pass with the
  same corrected source. This validates a non-ASCII extraction path only; a
  non-ASCII Windows username was not tested.
- Clean player-package input acceptance (`2026-07-31`): the rebuilt package in
  a path containing spaces launched and repeat-launched with packaged JAWS
  speech `READY`. After the keyboard-bridge launch paths were explicitly
  quoted, its package-local heartbeat advanced normally. The user confirmed
  arrow/Enter and additional keyboard inputs reached the game, physical
  controller presses were also recognized, and FCEUX paused while its main
  menu was open as intended. A later NVDA-only repeat launch found NVDA running
  with no JAWS process, selected `NVDA reason=auto`, reached speech status
  `READY`, and was manually confirmed speaking by the user. Refreshing
  `SDL.LuaScript` and `SDL.LastLoadLua`
  after graceful old-process shutdown preserved Lua startup on the repeat
  launch. This earlier ASCII-path process has been superseded by the clean
  Unicode-path acceptance above.
- FCEUX menu and teleport input acceptance (`2026-07-31`): the launcher-backed
  empty native keyboard profile, pause-on-menu setting, and suspended bridge
  kept an `Alt+F`, three-Down, Escape sequence out of the ROM; Mountain Cave
  stayed at `(0,7)` and the log contained no bridge activation in the interval.
  Right, Left, F, D, and Enter then produced clean press/release pairs. Eleven
  rapid selected-teleport activations did not reproduce a hard lock, although
  stale FCEUX `Down` initially made a new Shift press attempt `Shift+Down`
  before Enter. Teleport chords now require the non-modifier key to have a
  fresh edge. After reload, holding Shift first and tapping Enter produced no
  false directional activation, teleported exactly to F1 chest `(13,5)`, and
  released Enter after 7 frames; F/D immediately opened and closed the command
  menu. That focused pass ended neutral at `(13,5)`, with `buttons=0x00` and no
  pending suppression, facing, or teleport guard. The user's broader Tantegel
  pass then logged 21 successful teleports across travel targets, services, and
  NPCs; 25 trigger releases completed in 5-16 frames, multiple held NPC targets
  reached TALK dialogue, and there were zero release timeouts, OAM-stuck
  signatures, or bridge-lease expirations. Fresh probe
  `TANTEGEL_TELEPORT_VALIDATED_20260731` is neutral at World Map `(43,43)` with
  all guards clear. The 90-frame stale-key timeout remains a bounded recovery
  path; earlier timeout attempts recovered controls without needing Start.
  Verification passes 240 focused Lua tests, 11 bridge-policy tests,
  PowerShell/Lua syntax, and `git diff --check`.
- Mountain Cave completion (`2026-07-31`): travel guidance is live-validated
  in both directions between waypoint `(18,64)` and cave `(29,57)`. Both
  interior floors are decoded, all three coordinate-matched stair pairs work
  both ways, and B2 correctly separates the northwest and southeast dead-end
  stair pockets from the central treasure region. Source-only navigation
  reaches the F1 chest `(13,5)`, all four B2 chests, and central stair `(6,5)`.
  F1 top cells `(11,0)..(13,0)` passed clean same-origin probes in both
  directions after a normal-route arrival; after reload, source-only routing
  completed from chest `(13,5)` to ordinary interior `(10,1)` and back with no
  runtime blockers. Two manual returns and a normal-origin probe then confirmed
  `(8,1)->DOWN` into `(8,2)` is blocked; source now models both the north and
  south approaches to that upper-loop cell. A loaded-source chest-to-exit
  return completed without rerouting or adding a runtime blocker, and the user
  manually validated the corrected route as clean. The final B2 boundary cell `(1,0)` also passed a
  loaded-source round trip from stair A `(0,0)`. Chests were not deliberately
  opened during map QA.
- Magic Temple return-route revalidation (`2026-07-28`): a second manual
  `rimuldar_magic_temple` pass completed all 22 waypoints and entered Rimuldar
  `0x0B` at `(29,14)`. Seven bounded retry events recovered automatically,
  with no drift, seam brute-force fallback, timing-retry escalation,
  temporary blocker, or runtime blocker. Six battles occurred; four
  interrupted an active segment, and the route resumed safely. Fresh probe
  `TEMPLE_RETURN_VALIDATED_20260728` reports route `none`, no active path, and
  no runtime blocks at `(29,14)`.
- Magic Temple interior navigation (`2026-07-28`): live same-origin raw probes
  proved exit stair `(0,4)` is a passthrough and confirmed directional walls
  at `(2,4).east/west`, `(2,5).east/south/west`, and
  `(4,3).west`, `(4,4).west`, `(4,6).west`. With navigation modules reloaded
  and map-0x0E runtime blockers cleared, source-only autowalk completed
  `(3,6)->(0,4)` in 5 steps, then `(0,4)->(3,5)` in 6 steps and faced east
  toward the Old Man at `(4,5)`. That source-only interior pass ended at
  `(3,5)`, with no active path or runtime blocks. All 70 map-reader tests,
  Lua syntax, and `git diff --check` pass.
- Magic Temple / Rainbow Drop route (`2026-07-28`): the source-pinned
  `magic_temple` and `rimuldar_magic_temple` routes are live geometry-validated
  end to end. Outbound guidance reached `(108,109)`; the required `STAIRS`
  command entered Magic Temple `0x0E` at `(0,4)`. The sage exchanged the Stones
  of Sunlight and Staff of Rain for the Rainbow Drop while preserving
  Erdrick's Token. The same stair tile returned to World Map `(108,109)`, and
  the reverse route entered Rimuldar `0x0B` at `(29,14)`.
- Timing qualification: the reverse mountain pocket drifted from the intended
  `(107,111)` stop to `(106,111)`, while `(103,111)->LEFT` and
  `(101,107)->RIGHT` exhausted both retries but passed same-origin raw probes.
  The outbound route had equivalent timing-only hard stops at
  `(110,86)->LEFT`, `(102,107)->LEFT`, and `(104,113)->DOWN`. No runtime or
  permanent blockers were added. That reverse-route pass ended at Rimuldar
  `(29,14)`, route `none`, no active path or runtime blocks, HP `115/115`,
  MP `93/97`, and intact level-18 stats.
- Route-specific second timing retry (`2026-07-28`): queued routes now use
  `auto_step_route_block_retry_limit=2`; manual taps still use zero retries and
  non-route injected/probe steps still use the general one-retry setting. A
  post-reload Cantlin-to-Eastern-Great-Swamp forest pass live-exercised retry 2
  at `(60,93)->DOWN` and `(50,99)->DOWN`; both steps completed automatically.
  Three additional forest seams recovered on retry 1. The complete
  `(73,102)->(48,104)` corridor had zero hard timing stops, zero off-path
  drifts, and no runtime blockers. REPEL expiry interrupted once only after
  `(68,91)->(68,92)` had completed, and route continuation remained safe.
  Current live state is `(48,104)`, with `great_swamp_cantlin` active at
  `Southern plains west road` index 25. Verification passes 145 auto-step,
  113 route-manager, 127 overworld-route, and 1 config test plus Lua syntax,
  `git diff --check`, and the full repository harness; only the known optional
  WSL speech-dependency warnings remain.
- Cross-waypoint turn timing (`2026-07-26`): the final queued step before a
  perpendicular route carry now retains the shorter inject limit of 10 through
  its guarded re-press and bounded timing retry. Live checks passed in both
  directions at `(22,95)<->(23,95)`, on the long segment ending
  `(23,106)->(23,107)`, and through one-step turns
  `(23,107)->(22,107)->(22,108)`. Observed guarded re-presses stayed at 10
  without drift or blocker promotion. The deepest bounded retry did not recur
  after the final reload, so that exact branch remains deterministic-test
  evidence.
- An ordinary non-final `(23,102)->DOWN` step produced one timing-only false
  block after the edge had already passed, then succeeded on retry. Do not
  promote it to map data. Three combat interruptions resumed safely. Fresh
  final state is World Map `(22,108)`, no active path or runtime blocks,
  HP `84/100`, MP `72/90`, with level-17 stats intact. Verification passes 144
  auto-step, 113 route-manager, 127 overworld-route, and 43 battle tests plus
  Lua syntax, `git diff --check`, and the full repository harness; only the
  known optional WSL speech-dependency warnings remain.
- Hauksness-to-Cantlin named route (`2026-07-26`): the final
  `cantlin_hauksness` route is live-validated from Hauksness World Map entrance
  `(25,89)` through 57 strict waypoints. It entered Cantlin from `(73,101)`,
  emitted `event=arrived` at waypoint 57, and landed on map `0x0A` at `(15,0)`.
  Fresh probe `CANTLIN_ARRIVAL_20260726` showed route `none`, field control,
  controller byte `0x00`, and no runtime blocks.
- Two reverse-only forest jogs were replaced with live-observed north carries:
  `(50,100)->(50,99)` carried to `(50,98)` before the east lane to `(52,98)`,
  and `(64,93)->(64,92)` carried to `(64,91)` before the east lane to
  `(68,91)`. Route-local sustained-hold and settle controls make both carries
  explicit; no map blocker was added.
- The final east lane settled one column beyond the northern Cantlin road at
  `(74,91)`. Horizontal-first final recovery was therefore validated from
  `(74,99)`: left to `(73,99)`, then south into town. Combat interruptions and
  a REPEL-expiry dialogue safely retained/recovered the route. Other queued
  step retries during this pass remain executor-timing evidence, not map data.
- Final verification passes 127 overworld-route, 113 route-manager, 140
  auto-step, and 43 battle tests plus Lua syntax and `git diff --check`. The
  full harness completed all code/configuration checks; only the known optional
  WSL `accessible_output2` dependency check is nonzero.
- Cantlin-to-Hauksness named route (`2026-07-25`): the corrected explicit
  `hauksness_cantlin` route is live-validated from the actual Cantlin World Map
  exit landing `(73,102)` through all 58 waypoints. The final strict east step
  from `(24,89)` emitted arrival at Hauksness and changed to map `0x03`,
  position `(0,10)`; a fresh probe showed route `none`, menu/dialogue closed,
  and no runtime blocks. The route follows the western/southern forest rather
  than the rejected historical eastern trail.
- The same pass captured two recoverable settle overshoots:
  `(33,116)->(32,116)` and `(22,89)->(22,88)`. Both emitted
  `route_drift_off_path`, retained the next waypoint, and recovered on a fresh
  `auto_walk`. Queued block reports at `(70,91)->LEFT`, `(68,91)->DOWN`,
  `(56,95)->LEFT`, and `(20,110)->UP` passed same-origin raw probes. These are
  autowalk timing observations, not permanent map blockers.
- Fresh verification passes at 118 overworld-route, 113 route-manager, 140
  auto-step, and 43 battle tests. Lua syntax, `git diff --check`, and the full
  repository harness pass; WSL reports only the known optional
  `accessible_output2` warning plus the non-failing Windows-only speech bridge
  `cmd: not found` diagnostic.
- Route-aware overworld carry recovery (`2026-07-25`): the user confirmed the
  Hauksness guidance completed in both directions after loading the final
  source. A fresh post-run probe tagged
  `AUTOWALK_ROUTE_CARRY_20260725` confirmed World Map `(20,88)`, no active
  path, no runtime blocks, neutral controller byte `0x00`, and intact level-17
  stats: HP `94/100`, MP `40/90`, Strength `72`, Agility `70`, Attack `100`,
  Defense `85`, spells `0xFF/0x11`. The fresh log contains no stat-integrity
  transition/warning or movement-reset line. The pre-restart route log was not
  preserved, so do not claim a natural
  `AUTO_STEP_GUARDED_TWITCH_RELEASE` or
  `AUTO_STEP_FINAL_CARRY_ACCEPTED` occurrence from this pass, and no preserved
  final-segment log proves strict `carry=(nil,nil)` arrival. Exact guarded
  release, carry acceptance/rejection, and strict-final behavior remain
  deterministic-test evidence.
  Focused suites pass at 108 overworld-route, 113 route-manager, and 140
  auto-step tests; bytecode checks, `git diff --check`, and the full repository
  harness pass with only the known optional `accessible_output2` warning under
  WSL.
- Prior Cantlin route-status clarification (`2026-07-25`), now superseded by
  the bidirectional named-route validation: the direct overworld
  approach and town return are already live-validated. The approach enters
  from World Map `(73,103)` into Cantlin `(15,0)`. Selected-object return
  guidance reached southeast safe stand `(20,28)`, faced south, and uses
  `(20,29)` for the World Map transition, landing at `(73,102)`.
  `overworld_routes.lua` now defines both named directions.

- Rimuldar final manual service sweep (`2026-07-20`): every service route
  passed. The Weapons Merchant route temporarily could not plan while a roaming
  NPC occupied the corridor; waiting for that NPC to move and retrying worked.
  This is expected dynamic interference and does not justify another map block.

- Rimuldar Magic Key return correction (`2026-07-17`): the tempting direct
  route toward the east entrance through `(3,5)->(2,5)` is genuinely blocked;
  a natural-arrival probe failed with no NPC on the seam, so source retains
  `(2,5).east`. The earlier northwest-exit proof held LEFT long enough to hide
  an intermediate state. After selected Travel autowalk reached `(1,3)`, one
  normal LEFT reached `(0,3)` and stayed in Rimuldar; only the second LEFT
  exited to World Map `(102,72)`. A second normal-route recreation entered the
  same `(0,3)` stand, then UP moved along the x=0 strip to `(0,1)` without exit.
  Travel object `exit_0_3` now routes to `(0,3)` facing west, and row 3's false
  east-entry guard is removed. The nearby-exit route from `(4,5)` is six steps:
  `LEFT, UP, UP, LEFT, LEFT, LEFT`. The planner can alternatively continue
  north along x=0 and reverse the proven outer-bank route to east entrance
  `(29,13)` without touching the false bridge. `(4,3)->UP` remains blocked.
  Final reload validation on 2026-07-20 passed both routes. Selected Travel
  autowalk queued six steps from key stand `(4,5)`, reached `(0,3)`, faced west,
  and stayed in Rimuldar. After returning to `(4,5)`, east-exit autowalk queued
  51 steps, reversed the x=0/top-bank path, reached `(29,13)`, and faced east.
  Both routes cleared with no runtime blockers. Current focused validation is
  green in 67 map-reader, 99 object, and 21 pathfinder tests; the full
  seven-check smoke gate passes with Git Bash pinned inside Python.

- Rimuldar Wings-pocket and Weapons Merchant source-only validation
  (`2026-07-17`): the opened-door Wings return reached every promoted origin
  through normal movement, and each directional-only closure paired a route
  failure with a same-origin raw probe. Natural arrivals supersede old
  forced-origin open readings at `(22,24).north`, `(23,24).north`,
  `(24,24).north`, `(25,22).west`, and `(25,23).west`. Fixed `npc_13` at
  `(23,7)` now routes only to public stand `(23,9)`, facing north; `(24,7)`
  is enclosed and teleport-only. After a fresh reload with no runtime blocks,
  counter-to-entry and selected-object entry-to-counter autowalk both completed
  in 21 steps. TALK opened the weapon/armor shop. `Guard 2` at `(19,9)` caused
  two honest transient `No path found` attempts; retry succeeded after he
  moved, so no blocker was added. Final state is `(23,9)`, menu closed, and
  runtime blocks none. Focused suites and the full smoke runner pass.

- Rimuldar safe NPC parking validation (`2026-07-17`): with parking requested
  in `dw_access.ini`, auto-walk refuses proactive parking because map `0x0B`
  has a walkable origin. It logs
  `AUTO_WALK_NPC_PARK_SKIP map=0x0B reason=walkable_origin origin=(0,0)`
  and plans with `npc_mode=live_npcs`. A normal-entry 52-step route and a
  same-map reset repeat both crossed `(1,0)->(0,0)`, immediately continued
  south to `(0,1)` without a map change, and reached the Magic Key public
  stand `(4,5)`. Both runs ended with no runtime blocks. Do not change the
  marked completion waveform based on the earlier isolated stop at `(0,0)`;
  the complete route disproved that as a progression blocker. The direct
  merchant-to-entry shortcut through `(3,5)->LEFT` is confirmed blocked without
  NPC interference and modeled as `(2,5).east`. The corrected return can use
  the x=0 outer-bank route to the east entrance; the nearby west exit remains
  the shortest way out of town.

- Cantlin final manual checkpoint (`2026-07-15`): entrance-to-Magic-Key-Merchant
  routes passed in both directions with eastern door `(26,9)` open; with doors
  closed, the expected clean `No path found` result was confirmed. The Golem is
  defeated (`quest=0x42`). Fresh state at `(15,0)` has six keys, all door RAM
  slots cleared, no runtime blockers, and a new closed-door save state.

- Cantlin Magic Key Merchant route and NPC status (`2026-07-14`): navigator
  descriptions announce live NPC movement as stationary, roaming, or unknown.
  Fixed `npc_11` at `(27,6)` sells Magic Keys for 98 G from stand `(27,8)`,
  facing north across counter `(27,7)`. The route is intentionally gated by
  eastern door `(26,9)`, opened from `(25,9)` facing east. Closed-door route
  failures and same-origin raw probes confirmed `(27,5).north`, `(27,1).south`,
  and `(28,2).west`; runtime mirrors then returned cleanly through `(24,2)` and
  `(24,1)` to Town Entrance `(16,0)`. All three edges are permanent with focused
  regression coverage. Tests pass: objects 99, map reader 61, route manager 104.
  After clearing the runtime mirrors, source-only inspection kept all three
  approaches blocked and the closed-door planner returned clean `No path found`
  from `(16,0)` to `(27,8)`; runtime blockers are empty.
- Cantlin Tool Merchant 2 confirmed (2026-07-13): fixed `npc_12` at `(2,7)`
  opens a two-item tool shop from public stand `(4,7)` facing west. Its offers
  are Herb for 24 G and Torch for 8 G. Services now labels it `Tool Merchant 2`
  and uses the fixed counter stand. Blocker-hunt retries plus same-origin raw
  probes confirmed the counter approaches `(3,7).east` from `(4,7)->LEFT` and
  `(3,8).south` from `(3,9)->UP`; both are permanent directional blocks. After
  navigation-module reload and clearing the runtime overlay, source-only routes
  completed `(3,9)->(4,7)`, `(4,7)->(16,0)`, and `(16,0)->(4,7)` with no new
  blockers. Current hero is `(4,7)`, facing west, with no runtime blocks.
  Focused suites pass 61 map-reader and 98 object tests.
- Cantlin command-result numeric residue (2026-07-12): command-menu SEARCH
  and TAKE results picked up isolated status slices, producing trailing 6 and
  embedded 152 fragments. After the first reload, SEARCH page one was clean
  but page two still spoke "But there found 52 nothing." A closed-menu dump
  showed lower rows 6, 52, and 99 against status values LV 16, G 1520, and
  E 13994. The filter now derives every contiguous slice from visible status
  numbers and removes only suspicious unpunctuated redraw insertions. Reward,
  level-up, and shop-price numbers have preservation coverage. All 66 text and
  7 field-guard tests pass. Reload
  main.lua, recheck command results, then continue Person 2 at (2,7).
- Cantlin Person 2 approach pause (2026-07-12): hero and fixed Old Man 2 were
  overlapping at (27,6), so all four movement directions blocked. Treat those
  results as teleport/NPC-origin contamination, not walls. After clearing the
  temporary edges and relocating to entrance (15,1), a second status-scroll
  fragment, BillE13E1399 16Bill, blocked auto-walk before planning. The exact
  two-token fragment is now filtered with passing text and movement-guard
  regressions. Reload, then resume Person 2 at (2,7); no merchant label yet.
- Cantlin NPC/dialogue pass (2026-07-12): the user found an important Old Man
  1 clue, an armor-location clue from Merchant 1, and a possible second tool
  seller at Person 2. Keep Person 2 unconfirmed until its live TALK opens a
  shop prompt; reference material agrees Cantlin contains two tool shops.
  SEARCH at (27,6) exposed lower status-scroll residue 1520Bill3. Although no
  menu or prompt remained, the cached fragment blocked all object hotkeys.
  Passive-status filtering now recognizes that numeric/name/numeric pattern;
  63 text and 7 field-guard tests pass. Reload and recheck object controls at
  (27,6), then investigate Person 2 at (2,7).
- Cantlin fixed-service circuit (2026-07-12): after the stable-slot full
  reload, entrance round trips passed for the fixed Weapons Merchant and
  Premium Weapons Merchant. Fairy Water reached its fixed stand (20,13);
  return exposed (15,12).east from (16,12)->LEFT. Route retries and a clean
  same-origin raw probe agreed that it blocks. Mirroring the edge produced a
  clean return to (15,1), and source/tests now model it. All fixed essential
  service routes are clean; the roaming weapons merchant remains intentionally
  position-dependent. Focused counts remain 61 map and 97 object tests.
- Cantlin stable service identities (2026-07-12): an inactive NPC RAM slot
  renumbered duplicate Merchant labels, temporarily hiding the real Inn at
  (8,3) and mislabeling the dialogue-only merchant at (2,12) as Inn.
  Confirmed Cantlin roles now use stable NPC slot IDs before ordinal-name
  fallbacks. Live module reload restored slot 10 as Inn with stand (8,5)
  and slot 13 as non-service Radish Merchant. Source-only round trips from
  practical entrance (15,1) passed for the corrected Inn and Tool Merchant;
  the Fairy Water return also passed after full reload. No runtime blockers
  remain, and all 97 object tests pass.
- Cantlin premium equipment shop (`2026-07-12`): the fixed guard sprite at
  `(24,12)` sells Flame Sword for 9800 G and Silver Shield for 14800 G.
  The cursor reader spoke `Silver Harp` because the selected row contained
  only the ambiguous prefix `Silver` and its price; source now resolves that
  static 14800-G offer to `Silver Shield`. The first TALK proof from isolated
  `(24,13)` was not a public route. Live normal movement later crossed hidden
  type-15 `(26,12)` from `(27,12)->LEFT`; TALK there facing west opened the
  same shop across blocked counter cell `(25,12)`. Services now labels this
  NPC `Premium Weapons Merchant` and routes to `(26,12)` facing west.
  Moving Merchant 3 in the southwest locked building is Wynn/Hauksness lore,
  not a shop. That lore line exposed embedded status letters as
  `Wynn M ... G Hauksness`; dialogue cleanup now removes repeated isolated
  status letters but preserves a lone uppercase initial. Automated routes
  completed both directions between practical entrance `(15,1)` and premium
  stand `(26,12)` in 24 steps. The user then manually verified the
  Services-selected route, shop prompt, Flame Sword row, and Silver Shield row.
  Focused suites pass 61 map, 63 text, 19 merchant, and 96 object tests.

- Cantlin inventory and Fairy Water pass (`2026-07-12`): roaming slot 4 is
  the basic shop (Bamboo Pole through Large Shield); fixed slot 19 is the south
  upgrade shop (Hand Axe through Magic Armor). Woman 2 at `(22,13)` sells
  Fairy Water for 38 G from stand `(20,13)` facing east. The selected-service
  route from practical entrance `(15,1)` reached that stand cleanly. Return
  exposed `(16,13).east` from `(17,13)->LEFT`; route retries and a clean
  same-origin raw probe all blocked. Mirroring the edge produced a clean return,
  and the forward route completed again. Source/tests now include the edge.
  Earlier post-shop multi-token status residue is suppressed, and the user
  validated every command-menu option after full reload.


- Cantlin Tool Merchant and Inn validation (`2026-07-11`): the user confirmed
  the Tool Merchant route and the complete forward Inn route. Inn return found
  `(16,1).south` blocked from `(16,2)->UP`; direct and 3/3 raw probes agreed
  without contamination. After runtime mirroring, the route detoured through
  x=17 and reached Town Entrance `(16,0)`. Source now models `(16,1)` as fully
  blocked. Reload Lua before clearing the one-cell overlay.

- Cantlin north-lane validation (`2026-07-11`): the original carry-sensitive
  `(4,1)` to `(1,0)` route now stays in town through its seam retry and
  16-frame initial settle, then completes west. North approaches on
  `(1..3,1)` and `(7..13,1)` are clean 3/3 blockers; descents at `x=4`, `x=5`,
  `x=14` and `x=17..25` are open; x=6 now has clean blocked evidence.
  Returning north from `(23,1)` through `(23,0)` is a distinct world-map exit
  landing at `(73,102)`. Travel now routes to safe stand `(23,1)` facing north,
  and ordinary in-town paths guard `(23,0).south`.
  Descents at `x=26..28` each blocked under a normal-origin probe and clean
  3/3 verifier, so source models `(26..28,1).north`. With those three runtime
  mirrors, the 12-step west return from `(28,0)` reached Town Entrance `(16,0)`.
  Fresh source-only routing completed `9 east, 2 south` from `(16,0)` through
  open x=25 to `(25,2)` with no runtime blocks; x=18 also descended cleanly.
  Post-reload x=6 blocked directly and 3/3, and its runtime mirror correctly
  routed `1 west, 2 south` through open x=5.
  A teleport-seeded horizontal failure at `(17,0)->RIGHT` disappeared after
  normal west/east reacquisition; the live probe carried safely to `(19,0)`.
  Current state is Cantlin `(5,2)`, all five doors open, with the single x=6
  runtime mirror pending Lua reload.
  Focused counts are 88 auto-step, 51 crawler, 60 map-reader, and 94 object tests.
- Cantlin Travel-exit correction (`2026-07-10`): the only Travel object was an
  old placeholder at `(14,29)`, behind the lower striped damage barrier. Prior
  live movement already proved `(20,29)` immediately exits to the World Map,
  so the object now uses `exit_20_29`, routes to safe stand `(20,28)`, and faces
  south. The old `exit_14_29` is gone. Corrected-route cleanup also promoted
  verifier-clean `(23,27).east/west`, `(24,28).north`, and `(22,28).north`.
  Live selected-object validation completed at `(20,28)`, announced `exit
  here`, faced south, and stayed stable. Current runtime overlay has three
  cells mirroring those newest source edges; all five doors remain open.
  A later return from the fixed Weapons Merchant exposed `(23,27).north` from
  `(23,26)->DOWN`; the verifier blocked 3/3 with `npc_blocked=false`. With that
  fourth corrected-exit cell mirrored live, the return replanned around it and
  completed at `(20,28)` facing south.
- Cantlin essential-service route cleanup (`2026-07-10`): blocker-mode routes
  now complete both ways between practical entrance `(15,1)` and the Inn stand
  `(8,5)` (19 steps), Tool Merchant stand `(5,12)` (21 steps), and fixed
  Weapons Merchant stand `(25,26)` (35 steps). A separate return from
  `(22,27)` exposed `(21,27).east`; a clean same-origin verifier blocked 3/3,
  and the 33-step retry reached the entrance after source/runtime mirroring.
  Mobile Weapons Merchant 2 is position-dependent: the current slot-4 state
  at `(22,6)` lies inside the verified upper-east compartment. Both planners
  return `No path found`, and frontier analysis found zero hidden bridge
  candidates, so no real walls were removed. Earlier same-day live routes
  remain clean when this NPC wanders to a reachable position such as `(17,4)`.
  Follow-up TALK checks ruled out a hidden counter interaction from every side
  of the enclosure: north stand/target `(22,1)->(22,3)`, south
  `(22,8)->(22,6)`, west `(20,5)->(22,5)`, and east
  `(24,4)->(22,4)` each returned `There is no one there`. Slot 4 is now labeled
  `Roaming Weapons Merchant`; do not assign it a static stand or weaken the
  verified boundary model.
  A follow-up bouncing route was actually targeting the south `Exit to World
  Map` `(14,29)`, not practical entrance `(15,1)`. Cleaning that route and the
  subsequent coordinate route promoted seven verifier-clean approaches:
  `(19,28).east`, `(19,25).north`, `(17,24).east/north`,
  `(17,21).east/south`, and `(18,20).south`. With those mirrored live, blocker
  mode completed to `(15,1)` and remained stable across two position samples.
  One seam-retry arrival drifted one extra tile once, but a controlled normal
  step and the final route did not reproduce it. Current position is `(15,1)`,
  all five doors remain open, and five runtime cells mirror the newest source
  entries until the next script reload.
- Cantlin damage-barrier and reload-timing checkpoint (`2026-07-10`): the
  lower-center striped barrier is now modeled as 16 damage hazards across rows
  26-28, so ordinary route plans avoid it. The live route had crossed the top
  barrier row and left the hero at 4 HP; after recovery to `(9,25)`, blocker
  mode completed 30 safe steps to entrance `(15,1)`. `(12,27).north` is also a
  clean 3/3 directional block. The one-frame navigation reload repro changed
  from `NPCs. No objects` to a populated 19-NPC list after fresh object modules
  began synchronously priming their live-map list during command registration.
  Current checkpoint is `(15,1)`, all five doors open, menu/dialogue closed,
  one key, and no runtime blockers.
- Cantlin category reachability audit (`2026-07-10`): live reload validation
  proved the Services module-rebind fix; all four services enumerate correctly,
  and object-selected blocker mode routed three east to mobile Weapons Merchant
  2, faced south, and held the target. Reachability reports 4/4 Services, 1/1
  Travel, and 5/5 opened Doors reachable. NPCs were 18/19 reachable; the sole
  false negative was non-service Radish Merchant `(2,12)`, whose previously
  proven public TALK stand is `(4,12)` facing west. A fresh 22-step route from
  `(17,3)` reached that stand with no blocker or runtime patch. Explicit NPC
  role overrides can now carry interaction coordinates while remaining outside
  Services, and Radish Merchant uses the confirmed stand. All 92 object tests
  pass. Current checkpoint is `(4,12)`, all doors open, menu/dialogue closed,
  and no runtime blocks. Reload `main.lua` and expect NPC reachability to become
  19 reachable, 0 unreachable.
- Cantlin Merchant 2 route and Services reload (`2026-07-10`): user validation
  confirmed all command-menu actions, SPELL, ITEM, and the mobile Weapons
  Merchant speak cleanly after the `llE` fix. Blocker-mode walking completed
  from south merchant stand `(15,5)` to entrance `(15,1)` and back from the
  entrance to stand `(14,3)` beside Merchant 2 at `(14,4)`; both legs were
  clean and required no runtime blockers. The subsequent Services browser
  exposed stale module state after navigation reload: it announced `Services`
  but retained `Eastern Building Door (10 of 25)`. Route manager now rebinds
  the reloaded `objects` module; the focused stale-selection regression and all
  104 route-manager tests pass. Current live checkpoint is `(14,3)`, all five
  doors open, menu/dialogue closed, and no runtime blocks. Reload `main.lua`,
  verify the four-entry Services list, then validate object-selected auto-walk
  to the mobile Weapons Merchant.
- Cantlin pocket/fragment follow-up (`2026-07-10`): after reload verified the
  cleaned Services list, routing out of debug checkpoint `(1,1)` found
  `(2,1).west` and `(1,2).north`. Both were same-origin verified 3/3 blocked
  with clean state and promoted to directional source/tests. Runtime mirroring
  made both normal and skip-NPC planners visit only `(1,1)` before `No path
  found`, confirming the checkpoint is an isolated pocket rather than a public
  route origin. After repositioning to entrance `(15,1)`, the Merchant 2 route
  canceled twice on `PREV.dialogue_len=3`; the corrected empty-coordinate run
  captured exact phantom dialogue `llE`. The text filter now classifies this
  fused name/status token as passive noise, and continuous auto-walk uses the
  shared dialogue-blocking predicate while retaining real-dialogue stops.
  Focused checks pass: 58 map, 58 text, and 7 field-action-guard tests. Current
  live checkpoint is `(15,4)`, all five doors open, menu/dialogue closed, and
  no runtime blocks. Reload `main.lua`, then retry the frozen mobile Weapons
  Merchant 2 route from a freshly reported unoccupied adjacent coordinate.

- Cantlin dialogue-merchant cleanup (`2026-07-10`): Merchant 3 was frozen at
  `(4,27)` and TALK from `(5,27)` facing west produced the Wynn/Hauksness shop
  hint. Merchant 1 was frozen at `(1,0)` and TALK from `(1,1)` facing north
  produced the buried-treasure-behind-Wynn's-shop hint. Neither opened a shop
  prompt; both are ordinary dialogue NPCs. `objects.lua` now keeps their
  generic `Merchant 1` / `Merchant 3` labels under NPCs while excluding both
  from Services. The focused regression passes with all 92 object tests. A
  preceding frozen Merchant 3 route from `(25,26)` reached `(3,29)` but hit
  `route_churn_cap` after 33 blocked events and was classified as a command
  timing/state issue; its 19 suspected cells remain scratch evidence only.
  Current live checkpoint is `(1,1)`, all five doors open, menu/dialogue
  closed, NPCs frozen, and no runtime blocks. Reload `main.lua` before checking
  the cleaned Services list.

- Cantlin Merchant 7 bidirectional completion (`2026-07-09`): restored-state
  routing promoted 16 clean directional results across the entrance reset,
  forward route, and return route: `(8,24).south`, `(10,25).west`,
  `(23,11).north`, `(22,11).north`, `(21,11).north`, `(21,21).west/north`,
  `(21,26).east`, `(13,8).south`, `(17,14).north`, `(21,13).west`,
  `(23,21).north`, `(22,21).north`, `(24,24).east`, `(23,25).east`, and
  `(19,25).east`. Each same-origin verifier was 3/3 confirmed blocked with
  clean state. With the runtime mirrors active, uninterrupted routes completed
  entrance `(15,1)` to Merchant 7 stand `(25,26)`, stand back to entrance,
  and entrance to stand again. Current checkpoint is `(25,26)`, all five doors
  open, menu/dialogue closed, with nine post-restart runtime cells. Reload
  `main.lua` before the next service hunt.

- Cantlin Merchant 7 return/reverse pass (`2026-07-09`): from the public stand
  `(25,26)`, the route reached entrance `(15,1)` after promoting 15 clean,
  directional verifier results: `(25,22).south`, `(23,23).east`,
  `(24,22).south`, `(24,24).north`, `(26,22).south`, `(27,20).south`,
  `(24,14).south`, `(15,13).south`, `(16,14).south/west`,
  `(14,14).south`, `(13,14).south`, `(12,14).south/west`, and
  `(11,13).south`. The reverse entrance-to-stand run then promoted
  `(21,11).west` and `(21,26..28).west`, all direct-verified 3/3 with clean
  state. The next replan entered `(20,29)` from the north and immediately
  exited to the World Map, proving this physically passable south-edge cell is
  unsafe for ordinary in-town routes; `(20,29).north` is now a directional
  transition guard. Recovery succeeded via overworld `(73,103)->UP`, but
  re-entering Cantlin reset both runtime blockers and opened-door RAM. Current
  live checkpoint is Cantlin `(15,2)`, no runtime blocks, all doors closed,
  one key. Reload the all-doors-open save and `main.lua`, then retry
  `(15,1)->(25,26)` without allowing another south-edge transition.

- Cantlin Tool Merchant / Merchant 7 follow-up (`2026-07-09`): two
  additional verifier-clean edges, `(7,6).east` and `(9,6).west`, completed
  the Tool Merchant route in both directions between stand `(5,12)` and town
  entrance `(15,1)`. Merchant 3 was reached by targeted survey but proved
  mobile, so no role was assigned. Merchant 7 is stationary at `(27,26)`;
  route work to stand `(25,26)` promoted `(23,21).east`,
  `(24,22).north`, `(25,22).north`, `(26,22).north`, and
  `(27,24).north`, all direct-verified 3/3. TALK from the stand facing east
  opened the weapon/armor shop prompt, so Merchant 7 is now a second
  `Weapons Merchant` with a fixed public counter stand. Current live
  checkpoint is `(25,26)`, menu/dialogue closed, NPCs frozen, with seven
  current-pass runtime blocker cells. Reload `main.lua` before testing the
  new source label and blockers without that overlay.

- Cantlin Tool Merchant return-to-entrance pass (`2026-07-09`): after reload,
  the Services filter correctly exposed `Tool Merchant` at `(7,12)` with public
  stand `(5,12)` facing east. Route work back toward the practical entrance
  `(15,1)` promoted verifier-clean hidden-wall blockers in the upper/central
  service maze: `(6,1..4).west`, `(6,5).west`, `(6,6).south/west`,
  `(7,4).south`, `(7,7).south/west`, `(9,2).east`, `(9,3).east`,
  `(9,4).east/south`, `(10,1).south`, `(10,6).east/north`,
  `(10,7).east`, `(11,1).south`, `(11,4).north/west`, `(11,8).north`,
  `(12,1).south`, `(12,4).north/south`, `(12,8).north`, and
  `(13,2).west`, `(13,3).west`, `(13,5).west`, `(13,6).west`,
  `(13,7).west`. Each was same-origin `probe_edge_verify:...,3`,
  `moved=0 blocked=3`. Current live checkpoint is Cantlin `(10,5)`, NPCs
  frozen, menu closed, runtime overlay `count=25`; reload `main.lua` before
  judging this source batch without runtime blockers, then retry
  `auto_walk_blocker:15,1`.

- Cantlin Merchant 5 route pass (`2026-07-09`): after a reload baseline at
  `(8,6)` with all doors open and `RUNTIME_BLOCKS none`, the route toward
  Merchant 5 at `(2,12)` exposed a west-shop wall/counter cluster. Promoted
  verifier-clean blockers are `(8,11).north`, `(2,11).north`,
  `(3,11).east`, `(3,12).east`, `(3,13).east`, `(3,14).east`,
  `(3,15).east/south`, `(2,15).south`, `(1,16).east`, `(1,17).east`,
  `(2,18).north`, `(3,18).north`, `(4,18).north`, `(3,11).north`,
  `(1,11).north`, `(5,15).north`, `(6,15).north`, `(7,15).north`,
  `(8,15).north`, `(8,18).east`, `(1,18).south`, `(2,18).south`,
  `(3,18).south`, `(5,18).south`, and `(4,18).south`. Current live checkpoint
  is Cantlin `(4,19)`, NPCs frozen, menu closed, with current-pass runtime
  blocker cells `count=7`. Reload `main.lua` to absorb the source batch, then
  retry `auto_walk_blocker:2,13`; the latest planner route is `2 east, 1
  north, 5 west, 5 north, 1 east` to stand `(2,13)`, facing north.

- Cantlin service-route follow-up after reload (`2026-07-09`): live route
  decoding promoted additional Merchant 1-area blockers in
  `MAP_DIRECTIONAL_BLOCKS[0x0A]`: `(6,5).east`, `(7,6).north`,
  `(8,4).south`, `(9,6).north/south`, `(10,7).west`,
  `(10,8).south/west`, `(11,4).south`, `(11,8).south`, `(12,8).south`,
  plus the entrance-return `(16,1).east`. With runtime copies active, the
  route chain reached `(4,9)`, then the moving Merchant 1 contact area at
  `(8,7)` and `(8,6)`. Merchant 1 wandered during prompt attempts and ended
  at `(12,5)`, so this pass does not promote a Merchant 1 role label. Current
  live checkpoint was Cantlin `(8,6)`, NPCs frozen, runtime blocker cells
  `count=10`. Reload `main.lua` before judging these latest source blockers
  without the runtime overlay.

- Cantlin service-route decoding started from the all-doors-open save state
  (`2026-07-08`): live FCEUX routing from the practical entrance tile `(15,1)`
  to `Merchant 4`'s counter at `(8,5)` now succeeds after promoting verifier-
  clean directional blockers in `MAP_DIRECTIONAL_BLOCKS[0x0A]`. TALK from
  `(8,5)` facing north opened the live Inn prompt:
  `Welcome to the traveler's Inn. Room and board is 100 GOLD per night.`
  `objects.lua` now labels that service as `Inn`, matching the other town inn
  labels. Merchant 2 live TALK proof opened the weapon/armor prompt from an
  adjacent stand, and `objects.lua` now labels it `Weapons Merchant` while
  preserving adjacent-NPC routing; the entrance route is still being decoded.
  Post-reload follow-up promoted more verifier-clean Merchant 2 blockers:
  `(18,2).north`, `(18,7).south/west`, `(19,7).south`,
  `(20,7).south`, `(21,7).south`, `(22,7).south`, `(23,2).east`,
  `(23,3).east`, `(23,4..6).east`, and `(23,7).east/south`, in
  addition to the earlier service-route blockers. With those blockers active,
  live frontier search from `(24,2)` to Merchant 2 at `(22,5)` found no
  untested bridge candidates into the merchant-side component. A counter-stand
  experiment from `(24,4)` facing west while Merchant 2 was frozen at `(22,4)`
  returned `There is no one there`, so no fixed Cantlin Weapons Merchant stand
  has been promoted yet.

- Cantlin locked doors pinned (`2026-07-08`): the five guide-backed door-icon
  cells on map `0x0A` now have live FCEUX OPEN/door-RAM proof. Confirmed cells
  and public stands are `Eastern Building Door` `(26,9)` from `(25,9)` facing
  east, `Central Right Door` `(15,25)` from `(15,24)` facing south,
  `Central Left Door` `(14,25)` from `(14,24)` facing south,
  `Western Shop North Door` `(4,21)` from `(4,20)` facing south, and
  `Western Shop East Door` `(8,25)` from `(7,25)` facing east. Current live
  state after the final check was Cantlin `(7,25)`, keys `1`, door RAM
  `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`, no runtime blocks, and
  input byte `buttons=0x00`. Reload `main.lua` in FCEUX before judging the
  latest source-side door objects/routes.

- Cantlin Golem trigger confirmed in live FCEUX (`2026-07-13`): moving north
  from World Map `(73,101)` onto `(73,100)` completed the step, then started
  battle at `(73,100)` with `A Golem draws near!`. The battle snapshot had
  quest flags `0x40`; after victory they were `0x42`, confirming the one-time
  clear bit. Moving south from `(73,100)` then changed to map `0x0A` and landed
  in Cantlin at `(15,0)`. The earlier southern approach from `(73,103)` entered
  town without crossing this north-side boss trigger. Green Dragon, Werewolf,
  Starwyvern, and Wizard fights observed elsewhere in the area remain ordinary
  random encounters.

- Cantlin closed-door fixed-service pass (`2026-07-13`): baseline at actual
  entrance `(16,0)` had all door RAM slots zero and no runtime blockers. With
  NPCs frozen for each individual route leg, round trips passed to Tool
  Merchant 2 `(4,7)`, Inn `(8,5)`, Tool Merchant `(5,12)`, Fairy Water
  Merchant `(20,13)`, and Weapons Merchant `(25,26)`. Premium Weapons Merchant
  `(26,12)` correctly returned `No path found` with `reason=closed_door`. No
  new map blocker was promoted. Initial unfrozen failures at `(4,4)->DOWN` and
  `(11,0)->RIGHT` were roaming NPC occupancy, not terrain: the blocking slots
  reported movement `0x00` while idle, then later reported nonzero movement.
  After reloading the full-mobility-history parking fix, unfrozen round trips
  passed for all five reachable fixed services while parking six to eight
  roaming slots per leg. No NPC-block or map-blocker event occurred. One return
  paused at `(15,0)` because the command menu was open and completed after it
  was closed. Premium Weapons Merchant remained correctly door-gated. Roaming
  Weapons Merchant `npc_4`, observed at `(22,4)` and then `(22,5)`, was not
  currently reachable; selected-object navigation refused without moving.

- Hauksness overworld route completed for current playtesting (`2026-07-03`):
  source exposes Hauksness/Haukness/Damdara route guidance from the Kol-side
  overworld start at `(104,10)`, but now turns back through the Garinham-side
  connector instead of the stale Tantegel/Rock Mountain Cave branch. Live FCEUX
  validation reached Hauksness from the western route: `auto_walk_blocker:25,89`
  from `(15,93)` crossed row 89, stepped right from `(24,89)`, and entered
  `map=0x03 (Ruins of Hauksness)` at `(0,10)`. The patched source includes the
  validated western desert detours and warnings before the dangerous Hauksness
  approach. No fixed overworld boss triggered on entry; the difficult fights
  observed nearby appeared to be random encounters. The Western desert
  south-shelf and south-road approach-order fixes are live-verified: guidance
  corrects LEFT before descending from `(16,27)` and RIGHT before descending
  from the `(1,54)` carry landing. The full Hauksness-to-Kol return route was
  subsequently live-validated end-to-end on `2026-07-24`, entering Kol at
  `(19,23)` with no runtime blocks. Ordinary Kol selection now preserves the
  active `kol_hauksness` variant. Live geometry also proved that the northeast
  bridge approach at `(56,15)` and the Kol southwest-track approach at
  `(77,18)` must descend before heading east; the return route encodes both as
  vertical-first, and generic `kol` now encodes the southwest-track correction
  as well. After a full script restart, generic Kol guidance from `(54,15)`
  reached `(74,18)`, descended eight tiles to row 26, then moved ten tiles
  right to `(84,26)` without attempting `(77,18)->RIGHT`. Several other
  apparent blocks passed same-origin raw probes and remain classified as
  executor timing noise rather than map data. The return route's lower-pocket
  carry recovery is also reload-verified: from the reproduced carry landing
  `(25,93)`, guidance moved LEFT to column 24 before moving UP twice to
  `(24,91)`, then advanced to `Hauksness lower pocket` without runtime
  blockers.

- Hauksness interior objective route completed (`2026-07-24`): after a full
  script reload at exit `(0,10)`, runtime blockers were empty. Object guidance
  reached the safe Axe Knight stand `(17,12)`, faced east toward the fixed
  encounter at `(18,12)`, and restored all parked NPC slots. The fully loaded
  reverse route then returned from `(17,12)` to exit `(0,10)` and faced west,
  again with zero runtime blockers or deferred NPC restores. Starwyvern and
  Werewolf battles interrupted both directions but resumed cleanly. The final
  state retained correct level-17 stats. The object navigator intentionally
  exposes the visible Axe Knight encounter but does not reveal the buried
  Erdrick's Armor location.

- Kol speech/menu regression follow-up (`2026-06-29`): manual Kol entrance
  checks passed for command-menu open/close, SPELL entry, and ITEM browsing
  without stale `Bill` / `ll` fragments or bogus merchant prices. Two follow-up
  fixes are live-verified in `main.lua`: ITEM entry suppresses the delayed duplicate
  first-item announcement, and SPELL lower-dialogue absorption now allows
  lowercase spell-result text through while still absorbing uppercase spell-list
  rows. Post-reload bridge proof: casting RADIANT spoke both
  `Bill chanted the spell of RADIANT.` and `But nothing happened.`, and ITEM
  entry spoke `Items. Dragon's Scale` without immediately repeating
  `Dragon's Scale`.
  A final Kol Tool Merchant sell-list retest also passed after reload: the
  lower inventory rows spoke item names without repeated `Merchant. Gold...`
  summary spam. The visible game list only shows a price for the highlighted
  Herb row; other sell prices appear in the confirmation dialogue.

- Kol door/service routes clean (`2026-06-29`): after the West Side Door stand
  correction and return-route blocker cleanup, live FCEUX validation completed
  to-and-from autowalks for `West Side Door`, `Western Building Door`,
  `Tool Merchant`, `Weapons Merchant`, and `Inn`. Each return reached
  `Exit to World Map` at `(19,23)` and faced south; the validation log contains
  no blocker/no-path/interrupt markers for that pass.

- Tantegel Castle downstairs Magic Key merchant return polish (`2026-06-25`):
  routing from the Magic Key merchant back to the throne-room stairs exposed ten
  false shortcut edges in the east/northeast strip. Runtime-blocking
  `(22,6).north`, `(21,5).east`, `(21,4).east`, `(23,6).north`,
  `(23,9).north`, `(24,9).east`, `(24,10).east`, `(25,6).south`,
  `(17,6).south`, and `(15,5).east` let `auto_walk_blocker` reach the stairs
  at `(7,7)` through the long west detour. These are now modeled in
  `map_reader.lua`; reload `main.lua` in FCEUX before judging the live planner
  without the runtime overlay.
  The reverse route from the throne-room stairs back to the Magic Key merchant
  then confirmed `(13,9).west` from `(12,9)->RIGHT` and `(19,6).west` from
  `(18,6)->RIGHT`; with both runtime edges active, `auto_walk_blocker` reached
  the merchant stand at `(24,3)`. The `(18,6)->DOWN` retry moved on seam retry
  and should stay open.
  Main entrance route polish from the merchant then exposed a compact false
  wall/counter cluster plus lower east-lane cuts. The promoted runtime overlay
  is `(18,14).north`, `(18,15).west`, `(23,6).east`, `(25,6).north/west`,
  `(26,6).north/south`, `(27,6).east`, `(27,7).east/west`, and
  `(28,24..28).east`. A follow-up pass from `(23,3)` confirmed `(23,2).south`
  with same-origin `probe_edge:up`; with that edge added, `auto_walk_blocker`
  reached the exit stand at `(11,29)` and returned cleanly to the merchant
  stand at `(24,3)`.
  Sun Shrine stairs return-route polish then confirmed the east approaches into
  `(27,9)`, `(27,10)`, and `(27,12)..(27,19)` are blocked from the x=28 lane.
  With those runtime edges active, `auto_walk_blocker:7,7` reached the
  throne-room stairs from `(28,19)`, and `auto_walk_blocker:28,19` returned to
  the Sun Shrine-side stand. The sticky-looking x=28 vertical moves and the
  `(6,17)` east/west crossings recovered on seam retry and should stay open.
  Inside Sun Shrine map `0x0C`, the route from `Stairs to Tantegel Castle`
  `(0,4)` to the chest `(4,5)` and old-man stand `(4,7)` now closes the hidden
  direct cuts at `(3,3).north/west`, `(3,4).east/west`,
  `(3,5).east/west`, `(3,6).west/south`, `(4,3).north/south`,
  `(5,3).north/south`, `(6,3).north/east`, `(6,4).east/west`, and
  `(6,5).east/west` plus `(6,6).east`. The validated route descends the x=2
  lane, crosses row 7, approaches the chest/old-man area from the east, and
  returns to `(0,4)` by the lower row-7 bypass instead of cutting west or north
  from the chest-side pocket. A same-origin recheck of the suspected
  `(2,2)->DOWN` edge moved through `(2,3)`, so `(2,3).north` remains open.
  Reload `main.lua` before testing this route without runtime blocks.

- Brecconary Magic Key revisit complete (`2026-06-24`): locked-door placement,
  service routes, Fairy Water access, and exit/object-browser behavior are
  clean enough for the alpha-prep pass. Remaining Brecconary caveat is runtime
  only: FCEUX needs a manual Lua reload before the latest source fixes are live.

- Brecconary exit-tile object browser (`2026-06-24`): standing on the in-town
  west exit tile `(0,15)` with the pathability filter on `reachable` collapsed
  the scanner to `Exit to World Map: here (1 of 1)`. Live inspection showed the
  player was still on map `0x08`; `(0,15)` reports `walkable=false` because it
  is an engine boundary, while `(1,15)` is walkable and path debug can route
  `1 east` from the exit tile. `route_manager.lua` now seeds pathability from
  adjacent walkable cells when the player stands on a non-walkable boundary
  tile. The live workaround used `pathability_filter:all`, restoring
  `Exit to World Map: here (1 of 23)`.

- Brecconary Fairy Water route / input capture (`2026-06-24`): the northeast
  locked-door service route now treats the Fairy Water seller as a moving Woman
  sprite behind the counter at rows `(24,3)..(24,5)`, with one public TALK stand
  at `(22,4)` facing east and a temporary target hold at `(24,4)`. Fresh
  route/manual evidence closed the noisy NE
  counter shortcuts at `(20,3).east`, `(20,5).east`, `(21,2).south`,
  `(22,2).south`, and `(23,3..5).west`; these were route-specific findings,
  not broad-survey leftovers. Live prompt evidence at frame `02209` proved the
  `(22,4)` / `(24,4)` trigger; later failed `(22,row)` attempts were routing
  and target-hold errors, not new geometry.

- Garinham door and service-route polish (`2026-06-24`): fresh live checks
  confirmed the town door roster is still exactly the two modeled doors:
  `Grave Route Door` at `(17,10)` and `Locked Building Door` at `(4,6)`.
  `pathability_filter:reachable` reported no reachable door objects from the
  current public/lower corridor state, while the unreachable door filter
  reported those two doors. Walked-origin probes reclosed both lower hidden
  bridge candidates, `(18,11)->UP` into `(18,10)` and `(19,11)->UP` into
  `(19,10)`, with raw-hold timeouts and no NPC/runtime/directional block, so
  neither should be promoted as a passthrough. A follow-up route-to-door issue
  showed `Grave Route Door` was routing only to the north-side stand `(17,9)`,
  which is valid from the grave side but unreachable from the public side while
  door cell `(17,10)` is closed. A public-side verifier reached `(17,11)`,
  facing north toward the same expected door cell, so `objects.lua` now exposes
  both stands and lets route planning choose the reachable side. Public service
  route polish reached the Tool Merchant stand `(3,11)`, Weapons Merchant stand
  `(10,16)`, Inn stand `(15,15)`, and exit stand `(1,14)` in live
  `auto_walk_blocker` runs. One Weapons-to-Inn attempt was stopped by a live
  NPC at `(15,13)` and succeeded on retry. A later user-reported Inn clutter
  pass rechecked the
  previously transient `(14,16).west` and `(14,17).west` bumps from walked
  origins: `(13,16)->RIGHT` blocked twice, `(13,17)->RIGHT` blocked under
  autowalk plus direct probe, and the runtime overlay then reached the Inn
  stand. These two west-approach blockers are now promoted in `map_reader.lua`.
  The actual grave-stairs route then reopened when manual movement found the
  top-edge bypass: `(12,0)->RIGHT` entered `(13,0)`, `(13,0)->RIGHT` entered
  `(14,0)`, and `(14,0)->LEFT` returned to `(13,0)`. `(13,0)` and `(14,0)` are
  now Garinham passthrough cells. A follow-up route polish pass started from
  the user-reported `(9,3)->UP` blocker, closed the confirmed false shortcuts
  around the left building face, then proved the route continues
  `(14,0)->RIGHT` into hidden `(15,0)` and descends at `(15,0)->DOWN` to
  `(15,1)`. From there, live `auto_walk_blocker:19,0` reached the grave stairs
  through row 1. `(15,0)` is now also a passthrough, `(14,1).north` is closed,
  and static pathfinder coverage requires the `(13,0)->(14,0)->(15,0)->(15,1)`
  route shape. A post-reload continuation from `(6,7)` confirmed the remaining
  upper-entry false cuts `(6,7)->UP` and `(3,7)->UP`; with those runtime blocks
  active, the route reached `(19,0)` cleanly. Follow-up inspection showed the
  user-reported `(3,2)->WEST` was already modeled, while adjacent
  `(3,1)->LEFT` into `(2,1).east` was newly confirmed and promoted. Reload
  `main.lua` before judging the live planner.

- Swamp Cave entrance-to-entrance polish (`2026-06-23`): while walking the
  north-exit route toward `South Stairs Up`, same-origin `probe_edge:DOWN` at
  `(1,23)` confirmed the open-preview seam into `(1,24).north` is blocked.
  With runtime `add_blocked_edge:1,23,DOWN`, `auto_walk_blocker:0,29` detoured
  east through row 23, descended the x=3 column, and reached `(0,29)`. Timing
  retries at `(2,23)->RIGHT`, `(3,28)->DOWN`, and `(1,29)->LEFT` moved or were
  battle-interrupted and were not promoted.

- Swamp Cave south-stairs-to-Princess return polish (`2026-06-23`): from the
  x=0 return corridor, same-origin `probe_edge:RIGHT` at `(2,12)` confirmed
  the open-preview seam into `(3,12).west` is blocked. With only that new
  runtime block added, `auto_walk_blocker:5,19` reached the Princess talk stand
  through the opened Gwaelin door. A follow-up north-exit route check from
  `(3,13)` confirmed `(3,12).south` the same way, and the runtime-patched route
  reached `(0,0)`. A top-corridor return-to-Princess pass then confirmed
  `(1,2).west` from `(0,2)->RIGHT`, `(1,5).west` from `(0,5)->RIGHT`,
  `(2,6).west` plus `(1,5).south` / `(1,7).north` from the walked `(1,6)`
  pocket, and `(1,7).west` from `(0,7)->RIGHT`; with those active, the route
  reached `(5,19)` while `(0,8)->RIGHT` remained the first open re-entry.
  A later noisy-route pass from `(3,4)` closed `(3,5).north`, `(4,4).west`,
  `(2,6).north`, `(3,5).west`, `(2,3).south`, `(4,4).north`, and
  `(5,14).north`; with that overlay active, the route reached `(5,19)` after
  combat interruptions at `(2,17)`, `(2,18)`, and `(5,20)` cleared.
  `map_reader.lua` and `test_map_reader.lua` now cover these approaches and
  keep the relevant routes from retrying them.

- Swamp Cave north-exit return polish (`2026-06-23`): starting from the
  opened-door / Gwaelin branch side, `auto_walk_blocker:0,0` plus same-origin
  `probe_edge` checks promoted the remaining false shortcuts on the return to
  `North Exit to World Map`. New directional-only blockers cover
  `(4,16).south`, `(5,16).south`, `(3,17..19).east`, `(4,20).north/east`,
  `(4,12).south`, and `(2,7).south`. With the runtime overlay applied, the route
  detoured through row 21, climbed via `(2,13)..(2,8)`, entered the x=0 corridor
  at `(0,8)`, and reached `(0,0)`. `lua test_map_reader.lua`,
  `lua test_pathfinder.lua`, and `git diff --check` pass.

- Swamp Cave route polish (`2026-06-22`): after the dragon and Gwaelin door
  route were verified, targeted `auto_walk_blocker` passes cleaned the known
  routes between the opened Gwaelin door stand `(5,21)`, Princess talk stand
  `(5,19)`, and `South Stairs Up` `(0,29)`. `map_reader.lua` now models the
  route-derived directional blockers exposed by those passes, promotes the
  formerly mixed `(5,24)->LEFT` into `(4,24).east`, and adds passthrough cells
  `(2,16)..(2,18)` for the live-walked middle strip. Static regression tests
  keep the south-stairs route, reverse route to the Gwaelin door stand, and
  opened-door return route available while blocking the false shortcuts.
  Reload `main.lua` in FCEUX before judging the live planner without the
  runtime overlay.

- Garinham inner locked-building door (`2026-06-18`): live OPEN/door RAM
  confirmed the inner door cell at `(4,6)`, opened from the south stand
  `(4,7)` facing north. Passing through reaches the one-cell guard pocket at
  `(4,5)`: north into `(4,4)` blocked under same-origin raw probe with no
  NPC/runtime blocker, west/east are stationary guards at `(3,5)` and `(5,5)`,
  and south exits back through the opened door. `map_reader.lua` now models
  `(4,6)` as a floor-backed door and `(4,4).south` as blocked; `objects.lua`
  exposes the routeable `Locked Building Door`. Treat this as a key trap /
  event-gated pocket, not a route to the grave stairs.

- Garinham grave-return route cleanup (`2026-06-17`): live FCEUX found a
  viable escape from grave-return stairs `(19,0)` to the inn by leaving town:
  route to `(18,1)`, step right to the World Map at `(2,2)`, follow the
  Garinham overworld route to `(1,2)`, step right back into town at `(0,14)`,
  then route normally to the inn stand `(15,15)`. The inn route completed;
  transient bumps at `(14,16).west` and `(14,17).west` remain unpromoted
  because they were not same-origin re-probed. These two bumps were later
  rechecked and promoted during the 2026-06-24 Inn clutter pass. The return
  leg from the inn
  back to the grave stairs is not currently viable: the old `(19,10)`
  passthrough was verifier/teleport fallout, and same-origin route/probe
  evidence blocked `(19,11)->UP` into `(19,10)` repeatedly. With that bridge
  blocked at runtime, every ranked bridge candidate back to the grave-side
  component was also probed from a walked origin and blocked, including the
  row-10 candidates, `(13,1)->RIGHT`, `(12,3..6)->RIGHT`, row-7 north gates,
  and `(18,7..9)->RIGHT`. `map_reader.lua` no longer treats `(19,10)` as a
  passthrough. Treat the forward grave-to-inn escape as playable through the
  world map, but do not claim a clean inn-to-grave-stairs return route until a
  fresh non-teleport path is found.

- Garin's Grave wrap-up (`2026-06-17`): major route-decoding work for this
  dungeon is complete for current playtesting needs. The player manually
  validated the final B1 entrance/down-stairs route and the B2/B3 escape routes
  after the latest blocker patches. The Silver Harp path, Cursed Belt path,
  Cursed Belt return/escape, B1 entrance route, B2 northwest-side escape to
  `Stairs Up`, and B3/B4 stair pockets are stable enough to stop broad blocker
  hunting in this dungeon. Remaining Garin's Grave work should be driven by a
  fresh gameplay failure or by optional item/content polish, not by speculative
  route cleanup.

- Garin's Grave B1 entrance/stair route cleanup (`2026-06-16`): live FCEUX
  round-tripped between the dungeon entrance / `Stairs to Garinham` `(6,11)`
  and `Stairs Down` `(1,18)`. The forward route reached `(1,18)` with
  `RUNTIME_BLOCKS none`; the return route reached `(6,11)` after battle
  interruptions and timing retries were cleared. The route-derived false
  shortcut `(3,17)->RIGHT` was then rechecked from a normally walked origin and
  blocked twice under same-origin `probe_edge`, so `(4,17).west` is now
  patched in `map_reader.lua`. A follow-up from normally reached `(17,9)`
  blocked `(17,9)->LEFT` into `(16,9)` twice, superseding older mixed evidence
  and promoting `(16,9).east` as well. Pulling the remaining live runtime
  overlay before reload promoted `(17,8).south`, `(18,8).north`,
  `(7,10).north`, and `(19,12).north`. Follow-up `auto_walk_blocker` cleanup
  confirmed `(16,7)->DOWN` into `(16,8)` and normally reached
  `(17,18)->DOWN` into `(17,19)` as blocked under repeated same-origin probes,
  then found and confirmed the east/west entries `(18,19)->LEFT` and
  `(16,19)->RIGHT` into `(17,19)` the same way. `(16,8).north` and
  `(17,19).north/east/west` are now patched. Noisy `(18,8).south` remains
  unpromoted.

- Garin's Grave B3 NW object cleanup after Cursed Belt (`2026-06-16`): after
  the player claimed the Cursed Belt, the reachable-object filter from the
  `Northwest Stairs Up` component still showed false routes to `Upper Stairs
  Down` `(9,5)`, `Southeast Stairs Up` `(18,13)`, and `Southwest Stairs Up`
  `(2,17)`. Live FCEUX auto-walk plus same-origin probes confirmed
  `(5,1)->DOWN` blocks into `(5,2)` and `(1,6)->DOWN` blocks into `(1,7)`.
  With those runtime blockers active, all three stair targets returned
  `No path found`, and the reachable filter reported only the opened chest and
  local `Northwest Stairs Up`. These blockers are patched as `(5,2).north` and
  `(1,7).north`; reload Lua before judging the live planner without runtime
  overlays.

- Garin's Grave B2 west-chest escape route (`2026-06-16`): after returning
  from the B3 west chest path to the B2 northwest side, live FCEUX movement
  found the escape back to `Stairs Up` `(11,2)`. The route from
  `Northwest Stairs Down` `(1,1)` can step left into false-boundary cell
  `(0,1)`, continue down the left-edge strip through `(0,11)`, exit right to
  `(1,11)`, then use the bottom/right corridor to reach `(11,2)`. Same-origin
  probes also closed false shortcuts at `(1,2).north/south`, `(2,1).west`,
  `(2,2).west`, `(2,8).west`, `(1,9).north`, and `(1,9).west`; the last one
  prevents the planner from trying the blocked `(0,9)->RIGHT` shortcut. These
  B2 cells are now patched in `map_reader.lua`; reload Lua before judging the
  live planner against the cleaned model. The reverse route from B2 `Stairs Up`
  back toward `Northwest Stairs Down` is not yet live-proven and should be
  checked separately if object navigation exposes it.

- Garin's Grave B3 west chest / likely Cursed Belt route (`2026-06-16`): after
  manual Lua reload cleared runtime blocks, live FCEUX validation reached west
  chest `(1,1)` from `Northwest Stairs Up` `(14,1)` and returned back to the
  NW stair. The route uses the top-edge false-boundary cells `(8,0)`,
  `(9,0)`, and `(10,0)`, the left-edge strip `(0,2)` through `(0,6)`, and the
  chest-side false-wall cells `(1,2)` and `(2,2)`. Clean same-origin probes
  closed the false shortcuts exposed during validation: `(3,1).east`,
  `(1,3).west`, `(2,3).south`, `(3,3).east`, `(1,4).east/west`,
  `(1,5).east/south/west`, `(9,1).west`, and `(11,1).west`. These latest
  shortcut closures are now in `map_reader.lua`; reload once more before
  judging the live planner against the cleaned permanent model. The player has
  since opened the chest and confirmed the Cursed Belt.

- Garin's Grave B3 west chest / likely Cursed Belt NW/top-row closure
  (`2026-06-16`): historical intermediate note, now superseded by the validated
  NW-to-chest route above. Follow-up live FCEUX probes preserved the useful
  top-row finding but closed one false direct route. `(9,0)<->(10,0)` remains
  standable and bidirectionally passable, while clean same-origin probes
  blocked `(14,1)->LEFT`, `(9,0)->DOWN`, and `(10,2)->LEFT`, modeled as
  `(13,1).east`, `(9,1).north`, and `(9,2).east`. The later `(8,0)` plus
  left-edge strip route is the working approach.

- Garin's Grave B3 west chest / likely Cursed Belt southwest-side closure
  (`2026-06-15`): the latest live pass from the current B3 component promoted
  all same-origin probe-verified runtime blockers into the permanent model:
  `(3,1).west`, `(5,14).west`, `(5,15).east/west`,
  `(8,14).east/north/west`, `(8,15).west`, `(4,16).north/south`,
  `(5,16).south`, `(6,16).north/south`, `(7,16).north/south`,
  `(8,16).south`, `(6,18).north`, and `(8,18).north`. With the equivalent
  runtime overlay active, `debug_route_frontier:1,1,100` reported
  `target_reachable=false` and `hidden_bridge_candidates=0`; follow-up probes
  verified the top-ranked remaining candidates were already-modeled blockers.
  After manual FCEUX Lua reload, rerun the frontier/pathfind checks without
  runtime overlay data before continuing with the remaining same-origin probe
  candidates.

- Garin's Grave B3 west chest / likely Cursed Belt top-edge route
  (`2026-06-07`): the previous NW-side "local stair only" conclusion was
  partially superseded by a live false-boundary find at `10,0 west`. Manual
  movement and log evidence showed `(9,0)<->(10,0)` is standable and
  bidirectionally passable, while the planner had treated the top row as
  blocked by the generic dungeon-edge rule. A 2026-06-16 intermediate rerun
  proved that seam alone was not enough; the later validated route adds
  `(8,0)` and the left-edge strip to reach west chest `(1,1)`.

- Garin's Grave B3 west chest / likely Cursed Belt from NW side (`2026-06-07`):
  historical note now superseded by the top-edge passthrough finding above.
  entering B3 from B2 `Northwest Stairs Down` lands at `Northwest Stairs Up`
  `(14,1)`. Live same-origin probes closed the false route toward the west
  chest at `(1,1)`: `(10,1)->LEFT` blocks into `(9,1)`, row-2 down probes into
  `(10..15,3)` all block, and `(15,1/2)->RIGHT` blocks into `(16,1/2)`.
  With those nine runtime blocks active, `debug_pathfind_to:1,1` and
  `debug_pathfind_to:9,3` both returned `No path found`, and
  `pathability_filter:reachable` reported exactly one reachable object:
  `Northwest Stairs Up`. The permanent model now includes `(9,1).east`,
  `(10..15,3).north`, `(16,1).west`, and `(16,2).west`. After manual FCEUX
  reload, runtime blocks were empty, `debug_pathfind_to:1,1` still returned
  `No path found`, and the reachable-object filter still reported only
  `Northwest Stairs Up`.

- Garin's Grave B3 west chest / likely Cursed Belt from SE side (`2026-06-07`):
  the southeast/lower B3 component is not a route to the west chest at `(1,1)`.
  Same-origin probes confirmed the two remaining hidden-bridge false positives,
  `(6,19)->UP` and `(8,19)->UP`, block into `(6,18)` and `(8,18)`, now modeled
  as `(6,18).south` and `(8,18).south`. After those runtime closures, repeated
  `debug_route_frontier:1,1,60` checks reported `target_reachable=false` and
  `hidden_bridge_candidates=0`; final `debug_pathfind_to:1,1` from B3
  `(14,15)` returned `No path found [no_path] (visited=98 path=0)`.

- Garin's Grave B2 Central Stairs false route (`2026-06-07`): the last
  unresolved B2 branch to `Central Stairs Down` `(5,6)` was chased from the
  east-side component starting at `(13,4)`. Normal-route movement plus
  same-origin probes confirmed `(13,4)->LEFT`, `(9,8)->LEFT`, and
  `(13,6)->LEFT` are blocked, modeled as `(12,4).east`, `(8,8).east`, and
  `(12,6).east`. With those runtime edges active, `debug_pathfind_to:5,6`
  from `(13,6)` returned `No path found`. Battle-contaminated retries at
  `(11,8)` were disproved by clean post-combat probes: both left into
  `(10,8)` and right into `(12,8)` moved, so those edges stay open. After
  FCEUX reload/restart, runtime blocks were empty and the permanent pathfinder
  from B2 `Stairs Up` `(11,2)` returned `No path found` for both
  `debug_pathfind_to:5,6` and `debug_pathfind_to:1,1`. A manual reachable-object
  filter pass from the same anchor is still useful, but permanent route geometry
  now rejects both Central and Northwest false targets without runtime overlays.

- Garin's Grave B2 Northwest Stairs false route (`2026-06-07`): from the
  southwest-stair side, the planner's route to `Northwest Stairs Down` depended
  on the old `(5,10)` knot. Normal-route movement plus same-origin probes
  confirmed `(5,10)->UP` into `(5,9)` blocked, modeled as `(5,9).south`, and
  the reroute then exposed `(1,10)->RIGHT` into `(2,10)`, modeled as
  `(2,10).west`. With both runtime edges active, `debug_pathfind_to:1,1`
  returned `No path found` both from `(1,10)` and from the B2 entrance-side
  `Stairs Up` anchor `(11,2)`. Treat the previous Northwest Stairs route as
  false geometry, not a route that should stay open.

- Garin's Grave B3 Southeast Stairs Up pocket (`2026-06-07`): live FCEUX
  route pruning from the SE-stair landing collapsed the false route to the
  Silver Harp chest `(13,6)`. The pass followed `auto_walk:13,6` reroutes and
  promoted only normally reached same-origin `probe_edge` blockers after
  battle/menu interruptions were cleared. Important passable evidence:
  `(14,19)->RIGHT` reaches `(15,19)`, `(15,19)->UP` reaches `(15,18)`, and the
  bottom row itself is laterally passable; the hidden walls are the north/up
  approaches from that row and the southeast row-12-through-18 pocket seams.
  With the runtime overlay injected, `auto_walk:13,6` from `(12,19)` returned
  `No path found`. The permanent model and tests now include the confirmed
  SE-stair overlay. After a manual FCEUX Lua reload, the reachable-object list
  showed only the local `Northeast Stairs Up` return stair, so this component is
  closed for object-navigation purposes.

- Garin's Grave B3 Northeast Stairs Up pocket (`2026-06-07`): entering B3
  from B2 `Northeast Stairs Down` lands at `(18,1)`. The reachable object list
  initially over-reported 9 objects. Live same-origin probes confirmed the
  northwest/lower bypasses are sealed by `(16,1).east`, `(16,2).east`,
  `(17,3).north`, `(18,3).north`, and `(19,3).north`. With those runtime
  edges injected, `debug_pathfind_to:14,1` returns `No path found` and the
  reachable filter shows only local `Northeast Stairs Up`. One attempted
  `(17,2)->LEFT` probe was discarded because a Drollmagi battle interrupted
  it; the post-combat retry from the same tile provided the clean evidence.

- Garin's Grave B3 lower-stair Silver Harp route (`2026-06-06`): from
  `Lower Stairs Down` `(10,9)`, the route to the harp chest side is now clean
  both directions under live manual probing. Forward route uses the reroute
  around `(10,8)->UP`: `(10,8)->(11,8)->(12,8)->(13,8)->(13,7)->(13,6)`.
  Return route from the chest uses `(13,8)->(12,8)->(11,8)->(10,8)->(10,9)`.
  Promoted B3 seams are `(10,7).south` and `(13,9).north`. The live save
  already had the Silver Harp in inventory (`C1..C4 = 45 C3 0A 00`, nybble
  `0xA`), so taking the `(13,6)` chest reported it was empty.

- Garin's Grave B4 west/east stair connector (`2026-06-06`): the B4 connector
  between `West Stairs Up` `(0,4)` and `East Stairs Up` `(5,4)` is now stable
  in both directions under live FCEUX testing. West-to-east completed via the
  lower/middle route, and east-to-west completed by descending the east side to
  `(7,6)` and returning through the proven lower route to `(0,4)`. Teleport was
  not used as direct passability proof. The promoted B4 seam set now includes
  the earlier connector seams plus `(1,3).south`, `(1,5).east/north`,
  `(2,2).east`, `(2,6).east/north`, `(3,1).east/south`, `(3,7).east`,
  `(4,4).east`, `(5,2).east`, `(5,3).south`, `(5,5).north`,
  `(6,3).south`, `(6,5).east/north`, and `(7,7).north/west`. Keep
  autowalk-only candidates such as `(5,2).west`, `(7,1).west`, and
  `(6,3).north` unmodeled until directly confirmed.

- Garin's Grave B3 Silver Harp route clarification (`2026-06-06`): if the
  player is in the B3 `Central Stairs Up` pocket around `(6,11)`, do not try to
  open a path from there to `Lower Stairs Down`. Live route retries plus
  same-origin probes confirmed `(6,11)->LEFT` into `(5,11)` and
  `(7,11)->DOWN` into `(7,12)` are blocked; the model now represents these as
  `(5,11).east` and `(7,12).north`. From the B2 southwest branch, the Silver
  Harp route is intentionally counterintuitive: enter B3 at `(2,17)`, take
  `Upper Stairs Down` at `(9,5)`, cross B4 from `(0,4)` to `(5,4)`, then return
  to the B3 lower-stair side and continue toward the harp area.

- Garin's Grave B2 live stair cleanup (`2026-06-06`): the earlier
  planner-only result that all six B2 stair cells had routes is now superseded
  for live pathability. With normal-route evidence and current runtime seams,
  the entrance-side component at `(11,2)` routes to `Northeast Stairs Down`,
  `Southeast Stairs Down`, and `Southwest Stairs Down`; `Central Stairs Down`
  and `Northwest Stairs Down` currently return `No path found`. The Central
  route failed at `(12,2)->DOWN` into `(12,3)` with route evidence
  `blocked=7 moved=0`, then two same-origin `probe_edge:DOWN` checks blocked
  from normally reached `(12,2)`, so B2 `(12,3).north` is now modeled. Keep the
  teleport-artifact rule: do not use teleport-backed verifier movement as
  direct proof on these B2 seams. Live checks in the same pass completed
  Northeast, Southeast, Southwest, and the Southeast/Southwest/Northeast return
  routes with only self-clearing timing retries.

- Dungeon stair-label policy (`2026-06-06`): internal cave/dungeon stairs now
  avoid destination-floor spoilers while keeping useful visible information.
  Labels use spatial orientation plus `Up` or `Down`, such as
  `Northwest Stairs Down`, `Central Stairs Up`, `South Stairs Down`, or
  `Lower Stairs Down`. Do not label unexplored internal dungeon stairs with
  exact destination floors, branch purpose, return/progression/trap status, or
  treasure-route hints. Public landmark exits such as `Stairs to Garinham`
  remain explicit unless they prove confusing in play.

- Garin's Grave B2 stair-hub audit (`2026-06-05`): the extra stair objects on
  B2 are not a false-connectivity bug. From `Stairs Up` at `(11,2)`, the
  object browser and planner can legitimately reach all six B2 stair cells, and
  the local map references agree B2 is meant to be a stair hub. Do not seal
  those stair routes just to make the object list shorter. If one specific stair
  route fails live later, treat it as a targeted seam/timing investigation.

- Garin's Grave B1 B2 Door north-side approach (`2026-06-05`): the selected
  `B2 Door` object did not disappear, but it only knew the previously proven
  lower/south interaction stand `(17,18)` facing north. From the current
  north-side maze component, that stand was unreachable while the adjacent
  planner found a valid route to `(17,16)` facing south. `objects.lua` now keeps
  both proven stands and `route_manager.lua` chooses a reachable interaction
  point when the primary stand has no path. Before FCEUX reloaded the patch,
  the live workaround `auto_walk:17,16` reached `(17,16)` with no runtime
  blockers; manual next action was to face south and use `OPEN`.

- Garinham / Grave of Garinham investigation (`2026-05-26`): public Garinham
  service routing remains usable, and the hidden grave entrance is now
  confirmed. The old `(19,16)` east-door object was disproved by OPEN reporting
  `There is no door here`, so it is no longer exposed as a door. Live
  grave-route probes confirmed `(3,3)`, `(18,0)`, and `(19,0)` as scoped
  Garinham passthrough cells: `(3,4)->UP` enters the dark-wall route,
  `(18,1)->UP` enters the standable top-edge cell `(18,0)`, `(18,0)->UP` exits
  to `0x01` / World Map, and STAIRS from `(19,0)` enters map `0x18` /
  Garin's Grave B1. User manual follow-up confirmed the Grave B1 arrival tile
  is `(6,11)` and the return stairs come back to Garinham `(19,0)`. The old
  B1 `Stairs Down` placeholder at `(19,0)` was manually disproved; ROM table
  evidence places the B1 stair down at `(1,18)`, and live `inspect_tile`
  confirmed that tile is walkable. The three B1 chest entries are ROM-backed at
  `(11,0)`, `(12,0)`, and `(13,0)`. A follow-up disproved the row-1
  normalization idea: TAKE at `(13,1)` and `(13,2)` found nothing, while SEARCH
  at `(11,0)` and `(12,0)` reported a treasure box and forced teleport to
  `(13,0)` held stable. These three top-row treasure cells now override the
  generic dungeon edge boundary. User later validated all three chest locations
  by teleporting/walking to each and opening them. The chest reward readout was
  mangled as `Ofthou hast gained 12` because the y<=3 dialogue cleaner stripped
  every uppercase run, including `GOLD`; it now strips known command labels
  while preserving meaningful uppercase reward/item tokens. Follow-up
  manual OPEN/log reconstruction plus fresh `DOOR_STATE` places the
  grave-route door at door cell `(17,10)`, opened from `(17,9)` while facing
  south. A door-to-grave trail-blazing rerun then confirmed `(14,1).west`
  blocks 5/5, while `(19,11)->UP` into hidden bridge `(19,10)` moves 6/6. The
  first post-map-patch autowalk reached `(19,11)` but exposed stale movement
  state during the east-to-up turn; `auto_step.lua` now resets movement state
  during queued route turn/final settle frames. After reload, the reverse route
  from `(19,0)` toward the door drifted out to `0x01` / World Map from the
  upper-right edge, not a new door. Clean verifiers now model `(14,1).east` and
  `(15..18,2).north`; `(19,1)->DOWN` was mixed and remains unpromoted.
  Silver Harp return-route follow-up later confirmed `(19,0)->LEFT` into
  `(18,0)` blocks 5/5, so `(18,0).east` is now modeled; `(18,1)->UP` still
  moves into the top-edge/world-map transition and remains open.

- Sun Shrine first decode pass (`2026-05-25`): map `0x0C` is the Stones of
  Sunlight chamber. User confirmation showed the west-edge stairs return to
  Tantegel interior, so the object is now labeled `Stairs to Tantegel Castle`.
  The player lands at `(0,2)`, the return stairs are `(0,4)`, the chest is
  `(4,5)`, and the stationary old man is `(4,6)`. `MAP_PASSTHROUGH_CELLS[0x0C]`
  keeps `(0,2)`, `(0,4)`, and manually proven `(0,7)` open despite the generic
  x=0 interior boundary rule. Survey from interior tile `(1,7)` reached both
  old man and chest; the old man blocks the chest's south side only, while the
  chest route itself succeeds by standing on `(4,5)`. A quick entrance/west-edge
  validation route to the old man drifted heavily around row 7 but eventually
  reached `(4,7)`, faced north, and opened dialogue; treat this as noisy route
  execution, not map blockage. The chest was then opened and logged the Stones
  of Sunlight reward. Current live state is `map=0x0C x=4 y=5`,
  `OBJECT: Chest (opened): here`, `PATH_STATE target=nil`, and
  `RUNTIME_BLOCKS map=0x0C none`. The only survey failure was the return
  stairs, classified as route drift / command timing, not map blockage.

- Tantegel Castle map `0x04` route wrap-up (`2026-05-25`): routes to the Sun
  Shrine stairs/southeast exit and Magic Key Merchant are now usable enough for
  gameplay. They are still noisy, especially through the shrine approach and
  lower/key-merchant lanes, but live validation and user manual checks confirmed
  they can complete. The shrine is a rare/one-time destination, so do not spend
  more time polishing it unless failures recur. Latest Magic Key Merchant route
  readback completed at `(11,29)` with `PATH_STATE target=nil` and
  `RUNTIME_BLOCKS map=0x04 none`.

- Tantegel Sun Shrine stairs route revalidation (`2026-05-24`): after removing
  `(26,20)` from the modeled hazard cells and manually reloading Lua in FCEUX,
  the route completed cleanly from the throne/entrance side to the Sun Shrine
  stairs and also cleanly on the return route back to the throne-room stairs.
  The only remaining route blemish was a couple of drift-triggered reroutes near
  the throne-room stair cluster. Treat that as the existing stair-area drift
  polish issue, not as new blocker or hazard evidence.

- Emulator A/B note: the same-save bakeoff is complete, and `./launch_dw.sh`
  now defaults to FCEUX for normal gameplay. Use raw battery save data as the shared
  baseline, not emulator-native savestates: `--battery-save PATH` now accepts
  either FCEUX `.sav` or BizHawk `.SaveRAM` data and copies it to the selected
  emulator's expected save path. Current contest baseline:
  `project_resources/saves/emulator_bakeoff/dw1_bakeoff_king_save_2026-05-18.sav`,
  captured after a normal king save in FCEUX and verified as an 8192-byte raw
  save. Detailed bakeoff notes live in
  `project_resources/emulator_bakeoff/README.md`. The first FCEUX pass on
  2026-05-18 passed from a player-feel perspective: no observed emulator lag
  during castle routes, sage dialogue, object navigation/mode switching,
  overworld movement, or combat. Logs still showed the native `LeftAlt` latch,
  but it stayed quarantined: 10 `INPUT_STALE_ALT_IGNORED` and 10
  `INPUT_STUCK_ALT` entries, all `spoken=false`, with no player movement,
  speech spam, menu-focus issue, or route evidence contamination attributed to
  Alt. The only route blemishes were script-side: repeated
  `AUTO_WALK_NO_PATH_DETAIL ... reason=stationary_npc_blocker` at the castle
  exit and two Rimuldar overworld route blocks near `(93,49)` / `(93,52)`.
  BizHawk's same-save pass transferred the save cleanly and kept input clean
  (`left_alt=false` throughout), but player feel was worse than FCEUX:
  route start/seam work caused 1-2 second lag/audio cut-outs, `Shift+O` mode
  switching caused roughly one-second lag bursts, map transitions hitched
  slightly, and spell-menu navigation had small spikes. Logs support this:
  2 `ROUTE_PLAN_TIMING` entries at 550 ms and 1268 ms, 24
  `SEAM_BRUTE_FORCE`, 23 `AUTO_WALK_TIMING_RETRY`, 3 `PATH_RUNTIME_BLOCK`, and
  post-run `PPU_STATS reads=149279028`. Current bakeoff verdict: FCEUX is the
  better gameplay-feel path; BizHawk remains the better automated debugging
  path unless it gets tuned further.

- Rimuldar was the next guide target after exiting Swamp Cave to the south
  island. External orientation from Gamer Corner: Rimuldar entrance is
  `(29S,59E)`, which is local world coordinate `(102,72)` from the current
  Tantegel anchor; inn is 55 G; there are 2 locked doors; treasure is Wings;
  shops are Weapons/Armor and Magic Keys. Magic Keys cost 53 G in Rimuldar and
  this is the first key shop that does not itself require a key. Mike's RPG
  Center agrees on the key-shop price and lists the weapon/armor stock as
  Copper Sword, Hand Axe, Broad Sword, Half Plate, Full Plate, and Magic Armor.
  Gamer Corner recommends the west route around the craggy mountains from the
  Swamp Cave south side because it is safer, and warns that the Rimuldar area
  is dangerous for a level 8-9 hero; SLEEP is useful against the stronger
  monsters. `overworld_routes.lua` now has live-corrected guidance:
  `rimuldar` from `Swamp Cave South Entrance` `(104,49)` to `Rimuldar`
  `(102,72)`, plus `swamp_cave_south` for the return. The first guide-derived
  run worked well overall, but the live log corrected two bad turns: the
  craggy-notch segment must not retry blocked `(93,57)->UP`, and the town
  approach must not push east from `(97,72)` into the north-side wall. The
  route now drops through `(93,57)` on the west side and uses the manually
  proven east approach, entering Rimuldar from `(103,72)->LEFT`. Fixed
  `Merchant 2` / `npc_13` is the weapon/armor merchant at `(23,7)`. Earlier
  selected-teleport evidence incorrectly treated enclosed tile `(24,7)` as a
  public route target. Normal movement establishes `(23,9)` facing north as
  the sole public counter stand. Live merchant rows list Copper Sword 180 G,
  Hand Axe 560 G, Broad Sword 1500 G, Half Plate 1000 G, Full Plate 3000 G,
  and Magic Armor 7700 G. The
  old town exit object at `(15,14)` is invalid: teleporting there and walking
  around showed it is just an ordinary interior tile. Live `probe_edge:RIGHT`
  from `(29,13)` triggered
  `EVENT: map change -> 0x01 (World Map)` and landed at `(102,72)`, so Rimuldar
  now uses `(29,13)` facing east as its `Exit to World Map`. Follow-up user
  check confirmed the new exit object lines up correctly from the town side.
  Return-route follow-up found that the mountain notch is not reversible:
  `(92,57)->UP` is engine-blocked, and the old return route looped there. The
  cave return now uses the live-probed west-pocket detour through `(85,58)`,
  `(85,56)`, `(83,56)`, `(83,54)`, `(86,54)`, `(86,52)`, `(92,52)`,
  `(92,48)`, `(100,48)`, `(100,50)`, and `(104,50)` before stepping `UP` into
  the south cave entrance. A recovery variant catches recalculations from
  `(92,57)` and sends the player west instead of retrying the blocked notch.
  The next user pass from Swamp Cave South Entrance to Rimuldar succeeded.
  Polishing review adjusted two route-shape annoyances: the west-lake bend now
  steps right from `(89,72)` before going north, and the north-wall corner now
  goes up from `(97,71)` before going east, avoiding the repeatedly blocked
  `(97,71)->RIGHT` edge into `(98,71)`. Other blocked-looking entries in that
  run later moved and remain timing/noisy seam observations, not permanent map
  blockers. The first in-town walkabout to the weapon/armor merchant produced
  one real Rimuldar town seam worth modeling: `(28,14)->UP` into `(28,13)`
  blocked on both the queued route and seam retry, no NPC occupied either tile,
  and the valid exit route moved through `(29,14)->(29,13)` instead. The noisy
  `(27,15).west` seam self-disproved with a moved retry and stays open. The
  2026-07-17 normal-movement pass supersedes the old teleport target: keep the
  weapon/armor route on `(23,9)` facing north and do not restore `(24,7)` as a
  fallback. From entry `(29,14)`, the source-only route is `11 west, 5 north,
  5 east`; the return is `5 west, 5 south, 11 east`. Rimuldar `Merchant 3` is
  live-confirmed as the inn keeper at
  `(16,18)`. Early TALK proof from `(16,17)` facing south opened the 55 GOLD
  inn prompt, but that stand later proved unreachable from the public route.
  Follow-up live testing found the reachable stand at `(18,18)` facing west:
  TALK opened the same 55 GOLD inn prompt, and path debug from there reaches
  the town exit. `objects.lua` now makes `(18,18)` the primary Inn interaction
  point while preserving `(16,17)` as an alternate. The 2026-06-27 route
  polishing closed false cuts at
  `(15,17).north` and `(17,19).east`. Follow-up FCEUX checks showed the
  `(17,17)`/`(18,17)` seam is not bidirectional: `(17,17)->RIGHT` can move
  into `(18,17)`, but the entrance-to-Inn route proved `(18,17)->LEFT` still
  blocks, so `(17,17).east` remains modeled and this is not the missing public
  connector. Historical pre-2026-07-15 service work correctly identified
  `Old Man 1` at `(4,7)` as the Magic Key seller and `Merchant 1` as the
  greeting-only NPC, but it misidentified counter `(4,6)` as the player stand
  and then explored the wrong hidden-connector network. The following details
  remain only as local seam history: `(24,7)->UP` moved into `(24,6)` even though the ROM tile
  decodes as blocked, and the later key-route shakedown proved `(19,9)` is the
  real bridge around the false `(24,9)` north pocket. Further probing added
  the hidden row-8/column-13 connectors `(14,8)`, `(13,9)`, and `(13,8)`,
  the upper hidden turn `(16,8)`, plus the northwest strip `(1,8)` and
  `(1,7)`. A later live verifier found the missing west-strip connector:
  `(1,7)->RIGHT` into false-wall `(2,7)` moved 5/5, so `(2,7)` is now a
  passthrough. The same shakedown promoted confirmed directional-only blocks at
  `(24,12).south`, `(23,12).south`, `(25,11).east`, `(20,10).south/west`,
  `(21,11).west`, `(21,12).south/west`, `(24,8).south`, `(13,6).south`,
  `(13,8).east`, `(14,6).east/south`, `(13,7).east`, `(6,4).east`,
  `(6,5).east`, `(6,6).east`, `(2,6).west`, `(17,6).east`, and
  `(17,7).east`; the later weapon-route loop superseded the older
  `(25,12).south/east` uncertainty, but keep mixed or NPC-tainted seams such
  as `(23,10).south` and `(14,8).south` open. A live
  check after restart clarified that `(6,6)` itself is still standable:
  `(5,6)->RIGHT` moved manually and was mixed/passable under raw verifier, but
  `(7,6)->LEFT` into `(6,6)` confirmed 3/3 blocked. The guide was right that
  the key seller is trapped behind a small maze. Follow-up live/raw work added
  final maze passthroughs `(6,3)`, `(5,3)`, `(5,5)`, `(4,5)`, and `(3,5)`.
  It also sealed false exits `(3,6).north/east`, `(5,6).north/west`,
  `(6,4).north`, and `(6,5).north/west`. The latest loop investigation added real blockers at
  `(10,6).north`, `(12,6).south`, `(13,7).west`, `(13,9).south`,
  `(14,9).east/south`, `(15,9).south`, `(16,9).south`, and
  `(17,9).south`. The `(12,7)->RIGHT` and `(12,7)->UP` exits blocked 5/5,
  then reconfirmed 3/3 after a script restart. The next clean route pass added
  `(28,13).east`, `(17,9).east`, `(9,6).north/west`,
  `(12,6).north/west`, and `(13,6).north`, superseding the earlier
  mixed/unmodeled notes for `(9,6)` and `(17,9).east`. The return-side
  lower-lane loop then cleanly reached `(6,10)` and repeatedly proved two false
  exits before stale Alt resumed: `(6,10)->DOWN` into `(6,11)` and
  `(6,10)->RIGHT` into `(7,10)`, so `(6,11).north` and `(7,10).west` are now
  modeled. A follow-up manual pass discovered the one-way lower connector
  `(4,8)->DOWN` into `(4,9)`, and autowalk from `(4,10)` then proved two more
  bad-pocket exits: `(4,10)->DOWN` into `(4,11)` and `(5,10)->DOWN` into
  `(5,11)`, so `(4,11).north` and `(5,11).north` are now modeled. The next
  entrance-side route pass cleanly looped before stale Alt returned on
  `(9,10)->LEFT` into `(8,10)`, `(9,10)->DOWN` into `(9,11)`,
  `(9,13)->UP` into `(9,12)`, and `(9,13)->LEFT` into `(8,13)`, so those four
  directional approaches are now modeled too. The next both-direction pass
  sealed `(22,12).south`, `(9,12).east`, and `(8,14).east` on the inbound
  route, then showed the visible return pocket below `(3,11)` is a dead end:
  `(3,12).north` and `(4,11).west` are now modeled. Keep `(5,3).east` open for
  now. The route-back no-path was an NPC/model issue in the other direction:
  historical attempts to leave `(4,6)` by walking south into Old Man 1 at
  `(4,7)` repeatedly blocked, while TALK from `(4,6)` facing south still opened
  the Magic Key shop. That evidence led to the then-current `(4,6)` stand model,
  which the 2026-07-15 counter proof supersedes with `(4,5)`. The lower
  false-wall area around `(4,8)` and `(4,9)` is
  passthrough, but the seller's occupied `(4,7)` cell is not a return corridor.
  Follow-up testing showed `(5,7)` is only a one-way trap east of the seller: exits into
  `(5,6)`, `(4,7)`, `(6,7)`, and `(5,8)` all repeatedly blocked, so
  `(5,6).south`, `(4,7).east`, `(6,7).west`, and `(5,8).north` are modeled.
  The attempted 2026-06-28 removal of `(17,17).east` was reverted: the reverse
  movement clue was one-way, and the entrance-to-Inn route repeatedly blocked
  on `(18,17)->LEFT` into `(17,17)`. The latest blocker batch added
  `(7,15).south`, `(6,16).east`, and `(7,10).north`. Manual
  movement also proved `(7,9)<->(8,9)`, so `(8,9)` is now the return connector
  around the blocked `(7,10)` drop. The next pass added `(6,16).south`,
  `(5,16).south`, `(3,13).south`, `(3,15).north`, `(8,10).north`,
  `(10,6).east`, and `(6,3).east`, while manual walking proved the false-wall
  passthroughs `(1,14)`, `(2,14)`, `(3,14)`, `(8,7)`, `(8,8)`, and `(14,5)`.
  The newest clean pre-Alt batch adds blockers at `(4,16).south`,
  `(3,16).south`, `(7,11).south`, `(4,8).south`, `(6,8).south`,
  `(6,4).west`, and `(6,3).west`, and adds the live-walked false-wall cells
  `(4,14)` and `(5,14)`. The suspicious `(6,8)` behavior is still hidden
  passability, not a full-cell blocker; only the south approach is modeled.
  The latest route/manual pass adds blockers `(2,15).south`, `(3,16).west`,
  `(4,12).south`, `(3,13).east`, and `(5,2).south`, plus false-wall cells
  `(3,4)` and `(4,3)`. A historical check reopened `(4,6).north` under the
  stale assumption that `(4,6)` was the stand; the 2026-07-15 live route
  supersedes it because `(4,5)->DOWN` correctly hits the counter. Fresh
  2026-07-17 normal-arrival proof disproved the old `(4,3)->UP` exit claim.
  LEFT from `(1,3)` reaches the in-town northwest exit stand `(0,3)`; a second
  LEFT changes maps. `Northwest Exit to World Map` therefore routes to `(0,3)`
  facing west.
  `(4,2).south` remains blocked as a real wall, not a transition guard.
  Follow-up route/manual evidence adds
  false-wall cells `(1,5)`, `(1,13)`, `(3,9)`, and `(15,5)`, plus blockers
  `(3,15).west`, `(4,12).east`, `(5,11).south`, `(14,6).north`,
  `(24,12).north`, and `(25,11).west`. The newest clean log promotes
  `(2,15).west`, `(6,11).south`, `(8,12).west`, `(4,4).south`, and
  `(4,3).south`. The latest route-to-merchant loop then added `(7,14).west`
  and `(6,15).north` after repeated clean blocks from `(6,14)` before stale
  Alt returned. The next weapon/key-route pass promoted `(25,12).east/south`,
  `(21,6).west`, `(21,7).west`, `(8,13).west`, and `(7,14).north`; the
  initial no-path in that batch was likely `Old Man 2` occupying `(6,13)`,
  not terrain. Later route-shaped evidence superseded the old noisy/open
  `(1,7)->RIGHT` probe: repeated movement into `(2,7)` from the west failed and
  reached `blocked=18 moved=0`, so `(2,7).west` is now modeled as blocked while
  `(2,7)` stays a passable hidden cell. With that west approach closed, the
  then-current model needed an alternate bridge into the key-counter lane.
  Key-to-east-exit then remained no-path when NPC occupancy was modeled because
  the geometry-only route
  walks through the seller. Follow-up probing found `(5,9)` is a real lower-lane
  false-wall tile from `(4,9)->RIGHT` 5/5, but `(5,9)->UP` into `(5,8)` blocked
  from a forced origin. The upper-left candidate through `(1,4)/(0,5)` also
  failed: `(1,5)->UP` and `(1,5)->LEFT` each blocked 5/5. `(1,6)->LEFT` moved
  into `(0,6)` and changed to world map, so that was exit behavior, not the key
  stand route.

  Resolved normal-route check (`2026-07-15`, supersedes the old `(1,8)` bridge
  hypothesis):
  - External guide orientation and the NES map put the real access bridge at
    the far-left outer bank, `(1,3)`, not `(1,8)`.
  - Starting at the normal east entry `(29,14)`, raw normal movement stayed on
    map `0x0B` while walking north along `x=29` to `(29,2)`, west along row 2
    to `(21,2)`, north to `(21,0)`, west along `y=0` to `(0,0)`, south along
    `x=0` to `(0,3)`, and right across
    `(1,3)->(2,3)`. Entering `x=0` horizontally below `y=0` returned to the
    World Map, so the northwest turn must be made through `(0,0)`.
  - Design self-review disproved the simpler full-top-row interpretation.
    Normal movement crossed east through `(26,0)`, but `(26,0)->RIGHT` into
    fixed `Person 4` at `(27,0)` blocked with `npc_blocked=true`. Keep the
    live row-2 / x=21 jog in the end-to-end route.
  - Static `Merchant 1` at `(2,4)` correctly blocked the direct south step.
    The clean bypass moved through
    `(3,3)->(4,3)->(5,3)->(5,4)->(5,5)->(4,5)`.
  - `(4,5)->DOWN` into `(4,6)` blocked under both a timed hold and a same-origin
    raw probe because `(4,6)` is the shop counter. From `(4,5)` facing south,
    TALK opened `Magic keys! They will unlock any door. Dost thou wish to
    purchase one for 53 GOLD?` toward seller `(4,7)`. The true player stand is
    therefore `(4,5)`, not the stale `(4,6)` interaction override.
  - The route used no teleport, runtime block, opened door, quest-state change,
    or special cadence. After cancelling the prompt and auditing the upper
    route, final state was entry `(29,14)`, six keys, and
    `RUNTIME_BLOCKS map=0x0B none`.
  - Static follow-up, independently rechecked against the local ROM, found that
    all 27 consecutive interior-map pointer spans match
    `ceil(width*height/2)` when sorted by ROM address. Rimuldar is exactly 450
    bytes from pointer `$8B62` to `$8D24`, matching `30*30/2`: the ROM stores
    two block nibbles per byte.
    `get_raw_block_id()` already uses that layout, but `decompress_map()` still
    expands the low nibble as an RLE length. This and blanket boundary rejection
    explain the false A* network. Preserve this live route with failing tests
    before repairing the decoder, Rimuldar boundary corridor, and service stand.

  Older clean check (`2026-05-18`, partially superseded by the 2026-06-28
  cleanup and fully superseded for end-to-end merchant access by the
  2026-07-15 outer-bank route):
  - A post-recovery verifier disproved the noisy `(2,8).west` blocker:
    `probe_edge_verify:1,8,RIGHT,5` moved 5/5 into `(2,8)`.
  - A raw forced-origin reverse probe from `(2,8)->LEFT` moved back to `(1,8)`,
    so do not block `(1,8).east`.
  - Keep `(2,8).south` closed: `inspect_move:2,9,UP` still reports
    `approach_blocked=true`.
  - The corrected town-tileset live route then found one more connector:
    `(9,10)->LEFT` into `(8,10)` reconfirmed blocked 5/5, while
    `probe_edge_verify:9,10,UP,5` moved 5/5 into `(9,9)`.
  - Follow-up row-9 corridor checks matched the route: forced-origin
    `(9,9)->LEFT` moved into `(8,9)`, then `(8,9)->LEFT`, `(7,9)->LEFT`,
    `(6,9)->LEFT`, `(5,9)->LEFT`, `(4,9)->LEFT`, `(3,9)->LEFT`,
    `(2,9)->LEFT`, and `(1,9)->UP` each verified 5/5 passable.
  - The rest of the key-stand approach is live-confirmed:
    `(3,8)->UP`, `(3,7)->UP`, and `(3,6)->RIGHT` each verified 5/5 passable.
  - A ROM-backed local A* using the then-patched files and real ROM found a
    39-step route from `(29,14)` to the then-modeled key stand `(4,6)` while treating
    Old Man 1 at `(4,7)` as blocked.
  - After manual FCEUX reload, that historical live autowalk from the town
    entrance `(29,13)` queued 40 steps and reached `(4,6)`, faced south, held the merchant, and
    opened the 53 G Magic Key prompt. The first few failed attempts were input
    clutter from teleport/FCEUX bridge state, not map evidence: `(29,14).north`
    changed from 9 blocked observations to `noisy` when the same edge later
    moved, and `(2,7).south` also moved on retry. Do not promote either edge.
  - Follow-up Magic Key Merchant route cleanup (`2026-06-28`) superseded two
    row-9 verifier notes with route-shaped FCEUX evidence. The route and
    same-origin probes blocked `(9,10)->UP` into `(9,9).south` and
    `(12,10)->UP` into `(12,9).south`; both are now modeled while keeping
    `(9,9)` and `(12,9)` standable passthrough cells for other approaches.
    The same pass found `(1,8)->RIGHT` into `(2,8).west` blocked by route
    failure, same-origin probe, and 5/5 verifier. At that time, promoting the
    edge isolated the modeled merchant-side component. The 2026-07-15 route
    resolved the apparent contradiction: this seam is irrelevant because the
    real bridge is `(1,3)` on the outer-bank route.
  - Follow-up NPC chat found two useful clue NPCs. `Old Man 3` at `(3,23)`
    asks about a magic temple with a yes/no prompt; its public west stand is
    `(2,23)`, reached through the false-wall seam `(1,23)<->(2,23)` that moved
    both directions. `Old Man 4` / Howard at `(20,23)` repeats the Kol bath
    clue: four steps south of the bath is a magic item.
  - Practical Rimuldar verdict: all player-facing services and useful clue NPCs
    have enough live coverage for now. Leave full dialogue-only NPC route
    validation for optional polish. The inn / Wings chest pocket has two
    confirmed magic-key doors: the outer door at `(21,21)` and the inner Wings
    chest door at `(22,23)`. Current live cleanup confirms the outer door opens
    from the public stand `(21,20)` facing south, with `(21,22)` facing north as
    the inside-side stand. The Wings chest door opens from `(21,23)` facing east,
    with `(23,23)` facing west as the chest-side stand. After real manual opens,
    `report_door_state` showed `keys=2 slots=0=(21,21) 1=(22,23)`. The model now
    gates both floor-decoding cells as magic-key doors until opened-door RAM lists
    them; the nearby Wings chest object is `chest_7` at `(24,23)`. Full FCEUX
    validation reached the chest from the town exit `(29,13)` through both
    opened doors, and the return route from the chest back to `(29,13)` also
    completed.
    Clean FCEUX movement proved `(13,18)` is a real false-wall connector from
    `(13,19)` to the public side and back, but it is not the Wings-room escape.
    The lower row-25 hidden strip is real but isolated. The apparent
    `(21,23)->DOWN` throat into `(21,24)` moved only from a fresh forced
    origin; every legitimate door-side approach blocked there, raw held DOWN
    did not move, and OPEN while facing south reported "There is no door here."
    The earlier no-path from `(23,23)` to `exit_29_13` was missing the outer
    door and should not be treated as current route truth. Do not promote
    `(19,25).east`; that verifier was NPC-contaminated. The later opened-door
    route to the chest also confirmed `(22,22).west` is blocked from
    `(21,22)->RIGHT`; the valid route reaches the inner door stand by stepping
    south to `(21,23)`.
    Later door-side retesting explains the current no-route behavior around
    `(22,23)`: with opened-door RAM empty, `(22,24)->UP` into `(22,23)` and
    `(21,22)->UP` into `(21,21)` both inspect as `door_closed`, while
    user confirmation explains the empty slots: at least in Rimuldar, leaving
    the map closes opened magic-key doors and reopening them costs another key.
    Treat the inn doors as map-entry session state, not permanently unlocked
    doors. The direct north edge
    `(22,22)->UP` into `(22,21)` is a real directional wall
    (`probe_edge_verify:22,22,UP,3` blocked 3/3). After the user got north of
    that wall, exit autowalk exposed two clean blockers modeled as
    directional-only seams: `(16,19).south` and `(17,19).south`. A later
    2026-06-27 inn-route pass superseded the older mixed `(17,19).east`
    verifier: `(18,19)->LEFT` blocked during autowalk and same-origin raw
    probe, so `(17,19).east` is now promoted. Keep `(21,24).south` (moved 3/3)
    and `(15,24).south` (mixed 1 moved / 2 blocked) unpromoted.
    A later manual/autowalk mix reached the outer door route network and did
    leave town once: the log changed to World Map after stepping
    `(28,16)->RIGHT` into `(29,16)`. Since the clean current planner route to
    the modeled exit `(29,13)` does not use `(29,16)`, `(29,16).west` is now a
    transition guard, not a corridor seam. A later route/probe polish pass also
    confirmed `(29,16)->LEFT` is blocked, modeled as `(28,16).east`, so the
    row-16 false cut stays closed in both directions. The user believes the throne-room
    door stays open after unlocking; keep that as a possible special case, not
    a contradiction of Rimuldar doors resetting after map leave.
  The later `(2,5)` lead was also stale/noisy: fresh route and direct verifier
  evidence block
  `(1,5)->RIGHT` into `(2,5)`, so `(2,5).west` is now modeled while the cell
  stays standable for other approaches. The `(3,7)` counter-lane lead is solved
  through the newly exposed `(2,8)` bridge; `(3,9)->UP` into `(3,8)` remains
  blocked, so `(3,8).south` is still modeled. Follow-up frontier probes also
  close `(2,8).south`, `(5,8).south`, `(6,8).east`, `(6,7).east`, and
  `(6,2).east`.

- Swamp Cave interior first-pass orientation is now recorded. External guides
  agree it is a one-floor north/south tunnel to the Rimuldar island, with no
  treasure chests, one locked door, and Princess Gwaelin guarded by a Green
  Dragon as the side objective. The local grid is 6x30. The user tested the
  `x=0` corridor from both directions and found it open through `(0,25)`, where
  south access ends. Follow-up live evidence showed `(0,25)` is the west bend,
  not the exit stairs: STAIRS there says no stairs. The bottom-right alcove
  `(5,29)` is also not stairs. The ROM up-stair table points to the south-island
  stairs at `(0,29)`, reached from row 29. `map_reader.lua` now models
  `x=0,y=0..25` plus `(0,28)` and `(0,29)` as Swamp Cave passthrough cells, and
  leaves `(0,26)..(0,27)` closed. The south-exit return route also now has
  directional-only blockers for the lower-cave seams into `(1,24)`, `(1,27)`,
  `(2,28)`, and `(2,27)` that the route-shaped log showed as failed approaches.
  A follow-up auto-walk loop to `Stairs Up to South Island` was stopped after
  strongly reconfirming north-approach blocks into `(1,27)` from `(1,26)` and
  `(2,27)` from `(2,26)`, so those cells now block both the earlier upper
  approach and the looped lower approach where proven.
  Object browsing should no longer show both `Exit` and `Stairs Up` at `(0,0)`;
  it should show distinct `North Exit to World Map` and `Stairs Up to South
  Island` Travel objects. The south-exit stairs path
  from the row-29 exit area lands on the world map at `(104,49)`, exactly five
  tiles south of the known north entrance `(104,44)`, matching the guide offset
  from `(1S,61E)` to `(6S,61E)`. World-map Travel now exposes this as `Swamp
  Cave South Entrance` at `(104,49)`, while plain `Swamp Cave` remains the
  north entrance at `(104,44)`. Follow-up live route looping now has working
  auto-walk routes between `North Exit to World Map` and `Stairs Up to South
  Island` in both directions. Latest scary seam logs on the lower path are
  timing noise rather than permanent blocker evidence: several queued-route
  timeouts immediately moved on seam retry, and one pass was battle-interrupted.
  Runtime blocks and seam memory for map `0x15` were cleared afterward, with
  `RUNTIME_BLOCKS map=0x15 none` and `SEAM_SUMMARY map=0x15 total=0`. Next live
  priority was finding the real locked-door coordinate. Realm of Darkness'
  Swamp Cave map places Gwaelin and the Green Dragon behind a lower-right branch
  door, but the first local coordinate model was wrong: from `(5,23)`, OPEN
  reported "There is no door here." Follow-up live probes found the real cell:
  OPEN from both `(5,21)` and `(5,19)` reported "Thou hast not a key to use."
  Because the DW1 engine checks only the four adjacent tiles for OPEN, the
  shared adjacent coordinate is `(5,20)`. `Gwaelin Door` is now modeled at
  `(5,20)`, with the normal route stand at `(5,21)` facing north. The first
  south-stairs-to-door auto-walk then looped at `(3,23)`, repeatedly trying
  north into `(3,22)` and east into `(4,23)`. Direct probes confirmed both
  false edges blocked, so the map now models `(3,22).south` and `(4,23).west`
  as directional blockers. After reload, runtime blocks are clear and the live
  planner routes door stand `(5,21)` to the south stairs `(0,29)` in 13 steps,
  door stand to the north exit `(0,0)` in 26 steps, south stairs back to the
  door stand in 13 steps, and north exit back to the door stand in 26 steps.
  A final auto-walk retest was interrupted by a random Magician before the old
  loop site; Bill won the fight. Follow-up looping from `(3,26)` exposed one
  more real seam: `(3,24)->RIGHT` into `(4,24)` verified 3/3 blocked and is now
  modeled as `(4,24).west`. The nearby `(2,23)->UP` into `(2,22)` had mixed
  verify results, so it remains unmodeled. After reload, the post-battle route
  to `Gwaelin Door` now traces cleanly through `(4,26)->(5,26)->(5,25)`.
  A later auto-walk loop at `(5,23)` confirmed two more bad approaches:
  `(5,23)->UP` into `(5,22)` and `(5,23)->LEFT` into `(4,23)` both verified
  3/3 blocked. Disk now models `(5,22).south` and `(4,23).east` as additional
  directional seams. Static tests still find a route from the lower branch to
  the door stand; in the current live session, matching runtime edges were
  injected because the touch-plus-probe reload did not pick up the latest disk
  patch. The active detour from `(5,23)` to the door stand is
  `(5,24)->(4,24)->(4,23)->(4,22)->(4,21)->(5,21)`.
  The next loop confirmed `(4,25)->UP` into `(4,24)` as blocked 3/3, so disk
  now models `(4,24).south`. The adjacent `(5,24)->LEFT` edge had strong loop
  evidence but mixed verifier results, so it is runtime-only in the current
  session as `(4,24).east`, not permanent data. With both runtime guards
  active, the planner detours from `(5,24)` through
  `(5,25)->(4,25)->(3,25)->(3,24)->(3,23)->(2,23)->(2,22)`. A validation pass
  was interrupted by a Druin after 2 successful steps, so the remaining detour
  still needs a clean hostile-dungeon run.
  The next live loop/validation pass confirmed the lower-left detour has more
  one-way cave seams: `(2,23)->UP`, `(1,23)->UP`, `(0,21)->RIGHT`,
  `(0,20)->RIGHT`, `(0,22)->RIGHT`, and `(0,19)->RIGHT` all verified 3/3
  blocked and are now permanent directional blockers. With matching runtime
  guards, the live planner currently reaches for the row-18 re-entry:
  `(0,19)->(0,18)->(1,18)->(1,19)->(1,20)->(2,20)->(3,20)->(3,21)->(4,21)->(5,21)`.
  Validation of `(0,18)->RIGHT` was interrupted by a Magician, but later manual
  validation confirmed `(0,18)->RIGHT` and the rest of the x=0 corridor
  eastward through `(0,9)->RIGHT` are engine-blocked. `(0,8)` is the first
  eastward opening, so disk now models `(1,9).west` through `(1,18).west` and
  leaves `(1,8).west` open. With matching runtime guards active, the live
  planner from the current `(3,8)` position routes down the interior column:
  `(3,8)->(3,9)->(3,10)->(4,10)->...->(4,21)->(5,21)`.
  Green Dragon location is log-confirmed at map `0x15` position `(4,14)`.
  The first clean dragon start was frame `04027`: after reaching `(4,14)`,
  auto-walk attempted `DOWN` toward `(4,15)`, battle started at `(4,14)`, and
  frame `04095` reported "A Green Dragon draws near!" Later restarts/manual
  checks also produced Green Dragon snapshots at `(4,14)`. Treat the door route
  as a rescue-branch hazard, not a player-safe objective for the current level 9
  hero. After the dragon is defeated, the rescue target is near the opened door,
  not in the northern dragon pocket: from the opened door route, stand at
  `(5,19)`, face north, and TALK to Princess Gwaelin at `(5,18)`. The successful
  rescue dialogue confirmed Gwaelin, accepted the castle escort prompt, and
  changed `combat` from `0x08` to `0x09` while leaving the opened-door slot
  `0=(5,20)`. Object navigation now treats her as a Swamp Cave-only special NPC
  before that escort bit, and removes the target once `combat` bit `0x01` is
  set.

- Fresh overworld-route grinding notes: Tantegel to Kol now works rather well.
  A few points still needed manual navigation, but side-stepping a couple of
  tiles was enough to get back on course, so this is polish rather than a
  blocker. The reverse route from Kol back toward Tantegel also solved the
  major navigation problems and only needed minor manual adjustments. Kol to
  Northern Cave worked perfectly; the reverse had a few minor hiccups but
  worked well. A later Tantegel-to-Northern-Cave request exposed an unsupported
  far start: it tried to begin the Kol-side route near Rain Shrine and gave an
  unfeasible long segment. The route system now stages that request through
  Kol first, with speech explaining that Northern Cave starts from Kol. A
  follow-up route-guidance bug is also patched: with a route already active,
  selecting a different supported Travel destination and pressing route
  guidance should replace the active route instead of only rereading the old
  route.

- Swamp Cave overworld routing has been corrected after live probes showed the
  first cave spur was a dead pocket. The earlier north approach through
  `(100,35)`, `(104,39)`, and `(104,42)` can lure the route into x104/x107
  pockets where southward movement blocks before the entrance row. The current
  route backs out through the Kol south-road jog to `Kol bridge east lane`,
  descends to `Swamp Cave lower west approach` at `(94,40)`, drops onto the
  lower swamp lane at `(94,41)`, crosses the freshly rechecked row-41 lane to
  `(97,41)`, then uses `(97,42)`, `(102,42)`, `(102,43)`, and `(104,43)` before
  stepping down into the cave trigger at `(104,44)`. Live testing found the
  x92 entry was still blocked: `(92,40)->DOWN` and `(93,40)->DOWN` blocked,
  while `(94,40)->DOWN`, `(95,40)->DOWN`, `(96,40)->DOWN`, and
  `(97,40)->DOWN` moved. The row-41 connector from `(94,41)` eastward was
  rechecked after the emulator lockup and moved cleanly. After this patch, the
  user reached Swamp Cave live: the log recorded map change to `0x15` and
  `OVERWORLD_ROUTE: event=arrived route=swamp_cave_bridge waypoint=Swamp Cave`.

- Swamp Cave remains a Kol-side route for the next push toward
  Rimuldar. External orientation: Gamer Corner lists the Swamp Cave entrance
  as `(1S,61E)`, matching the existing `overworld_swamp_cave` landmark at
  `(104,44)`; Mike's RPG Center places the cave far south of Kol near the
  bridge; Gamer Corner's Rimuldar walkthrough confirms the cave is south of
  Kol and warns that the approach crosses poison swamp. The route is staged
  as a Kol-side destination rather than a full all-map route. From far starts,
  selecting `Swamp Cave` should start the Kol route first. From Kol it reuses
  the known `Kol forest west edge` / `West of Kol north lane` / `Kol south
  road` chain, then uses the lower bridge/swamp approach above. A bridge-side
  variant starts from `Kol southwest bridge` and joins at `Kol bridge east
  lane`. Return routing is now wired as `kol_swamp_cave`: from the cave exit it
  backs out through `(104,43)`, `(102,43)`, `(102,42)`, `(97,42)`, `(97,41)`,
  `(94,41)`, `(94,40)`, crosses west at row 40 before climbing to
  `Kol bridge east lane`, then follows the Kol south-road and forest return to
  `(104,10)`. It warns about the poison swamp on the return. The user tested
  both directions live after wiring the return; there are a few polish-level
  rough edges, but no major blocker remains before entering Swamp Cave.

- Dialogue polish from the Garinham/grinding session is working in live play.
  The STATUS command now reads the full status line from memory and no longer
  gets interrupted by the lower visual equipment rows. After combat, object
  navigation no longer remains stuck behind the stale "Wait for dialogue to
  finish" guard once rewards are cleared; a Ghost fight with a level-up logged
  `dialogue cache cleared: lower window empty`, then object navigation worked
  normally. Current wrap-up position check: world map `(21,10)`.

- Combat fast-action speech is now queued instead of interrupting. The
  previous fast path still detects complete attack/damage sentences quickly,
  but normal round messages no longer call interrupting speech, so closely
  spaced lines such as `Bill attacks`, enemy attacks, and HP loss should stop
  cutting one another off. Battle start/opening lines still interrupt so a new
  encounter is announced promptly.

- Level-up stat pages now preserve numeric-only continuation rows. Live FCEUX
  evidence from the level-15 to level-16 Magidrakee fight showed the lower
  dialogue reader speaking `Thy power increases by Thy Response Speed
  increases by 6.` while the visible rows were `Thy power increases by` / `4.`
  / `Thy Response Speed` / `increases by 6.` The lower dialogue filter now
  keeps numeric-only rows only when they complete an incomplete
  `increase(s)/reduced/decreased by` phrase, so level-up stat values should not
  be dropped while ordinary status-row filtering remains intact. Follow-up live
  speech showed stale `Gold` tiles leaking into stat labels such as
  `Thy Response Speed Gold increases by 6.` and
  `Thy Maximum Hit Points Gold increase by 6.`; those artifacts broke battle
  overlap detection and caused earlier stat rows to repeat. `battle.lua` now
  removes leaked `Gold` only when it appears between a `Thy ...` stat label and
  an `increase(s) by` phrase, preserving real reward text such as
  `Thy GOLD increases`. FCEUX needs a manual Lua reload before judging the
  final follow-up live.

- Overworld safety-route waypoints around Garinham east field and Erdrick's
  Cave road have been tightened from live grinding evidence. The old route
  aimed too coarsely from `Garinham ridge entry` to `Garinham east field`, and
  then from `(21,11)` straight south toward `Erdrick's Cave road`; logs showed
  those south moves timing out while the player successfully used an east-first
  jog through `(20,7)`, `(21,10)`, `(23,11)`, and `(23,13)`. The safety routes
  now use explicit `Garinham field east lane`, `Garinham field road bend`, and
  cave-road lane markers, with regression coverage proving auto-walk starts
  east rather than south from `(19,7)` and `(21,11)`. Live reload/retest is
  still needed because the command log was stale when this patch was made.

- Route guidance should no longer steal object focus. Starting or checking an
  active overworld route was explicitly selecting the current `route_*`
  waypoint object, so normal route progress could appear to change the focused
  destination automatically. Guidance now requests a deferred route-marker
  refresh without selecting the marker; the original Travel destination should
  remain focused while `auto_walk` still follows the active route.

- Kol is now available as an overworld guided route. Select the `Kol` Travel
  landmark or run `start_overworld_route:kol`; aliases also include `kol town`,
  `kol village`, `fairy flute`, `faerie flute`, and `faeries flute`. Live
  shakedown disproved the earlier direct east-pocket lane: raw probes from
  `(57,38)` blocked east into `(58,38)` and also blocked north/south from that
  tile. The route now follows the Galenholm/Garinham-style path: western bridge
  road, cave road, east across the northeast bridge, southeast to the bridge
  southwest of Kol, then north and east into Kol's forest. The northeast bridge
  route now uses a lower-lane jog through `(58,18)`, `(59,19)`, `(61,19)`, and
  `(61,18)` after logs showed row-18 pullbacks near `(60,18)`. Static tests
  expect the north-side approach from `(60,17)` to start `right`, not `down`.
  The final reload did pick up the source change: live movement from `(60,17)`
  still showed `down` into `(60,18)` as bad, while `right` to `(61,17)` and
  then `down` to `(61,18)` moved cleanly. A Red Slime battle interrupted before
  a clean queued `auto_walk` retest, so retry that command near the bridge.
  The later south-road issue was also patched from live movement: after
  `Kol southwest bridge`, the route should now go east through `(92,37)`,
  jog through `(92,36)`, `(93,36)`, `(93,35)`, and `(96,35)`, then treat
  `(96,32)` as `Kol south road`. A later full-route pass proved direct north at
  `(96,28) -> UP` genuinely blocked. The route now steps east through
  `(98,32)`, climbs to `(98,26)`, and rejoins at `(96,21)`. After reload, the
  x98 north segment completed normally to `(98,26)` with no runtime blockers.

- Kol service decoding is staged. Local reference images and a text
  transcription are now in `project_resources/maps/kol/`: Mike's map page,
  Realm/VGMaps town map, Gamer Corner, StrategyWiki, and related guide facts
  agree on the important first services. The inn is 20 G and appears in the
  northeast building; the item/tool shop sells Herb, Torch, Dragon's Scale, and
  Wings; the weapon/armor shop sells Copper Sword, Hand Axe, Half Plate, Full
  Plate, and Small Shield; the Fairy Flute is hidden four steps south of the
  bath. The bath/search clue is now decoded: Woman 2 at `(12,1)` talks about
  the bath, the local map image has the bath/water tile at `(9,2)`, and the
  modeled hidden search tile is `(9,6)` in the Treasure filter as `Disturbed
  Earth Near Bath`. Old Man 1 has a current pathable flute-clue route at
  `(2,13)`, and Old Man 4 has a current pathable better-weapons clue route at
  `(1,1)`.

- A Kol-side route to the harp/Staff of Rain shrine is staged as `Northern
  Cave`. Select the `Northern Cave` Travel object or run
  `start_overworld_route:rain shrine`; aliases also include `staff of rain`,
  `harp shrine`, `silver harp`, `cave west of kol`, and `shrine west of kol`.
  From world-map Kol `(104,10)`, the route should leave through `Kol forest
  west edge` `(96,13)`, then `West of Kol forest bend` `(92,10)`, then take a
  long south-and-west detour around the water/mountain gap before approaching
  `Northern Cave` `(81,1)`. Live testing exposed the old bad pocket: from
  `(91,5)`, the route was trying to pull west/north toward `(83,3)`, but that
  side is separated by water and mountains. After reload, a route recalculation
  from `(91,5)` should target `West of Kol forest bend` and head south toward
  the new detour, not west into the gap. The user later reached the cave live.
  The return to Kol now has a `kol_rain_shrine` variant that reverses the Rain
  Shrine approach from `(81,1)` back to Kol; selecting Kol or recalculating
  near the shrine should start west toward `Rain shrine entrance approach`
  instead of far south toward the old Kol chain.

- Northern Cave now has a fully connected return to Tantegel. Selecting the
  castle near `(81,1)` follows a non-entry copy of `kol_rain_shrine`, hands off
  at Kol west doorstep `(103,10)`, and continues on `tantegel_kol`. Two reverse
  turns require explicit horizontal-first travel: from `(80,2)`, move west to
  column 78 before descending to `(78,3)`; from `(76,5)`, move west to column
  75 before the long descent. The final continuous acceptance run crossed both
  corrected turns, bypassed Kol without a map change, and entered Tantegel
  Castle at `(11,29)` with no retries, blockers, drift, cancellation, battle,
  or runtime-block injection.

- Swamp Cave's north exit now has a connected return to Tantegel. Selecting the
  castle near `(104,44)` follows the established non-entry
  `kol_swamp_cave_staging` return, hands off at Kol west doorstep `(103,10)`,
  and continues on `tantegel_kol`. The loaded continuous run bypassed Kol
  without a map change and entered Tantegel Castle at `(11,29)`. The first
  north step used one turn-repress recovery; the remainder completed with no
  blocked step, timeout retry, drift, cancellation, battle, or runtime-block
  injection.

- The first connected itinerary, `Tantegel -> Kol -> Northern Cave`, is live-
  accepted. Starting Northern Cave at Tantegel `(43,43)` kept Northern Cave as
  the final destination while status named Kol as the current leg. Entering
  Kol emitted a handoff to `Kol forest west edge` index 2 and did not start
  movement; the hero remained at Kol `(19,23)` with no active path. Map refresh
  selects the nearby Kol landmark on return to the World Map, so bare `U` now
  explicitly follows the active route rather than interpreting that automatic
  selection as a destination change. With `Kol` still selected and
  `northern_cave` active, loaded FCEUX completed the 11-step segment from
  `(104,10)` to `(96,13)`, announced `West of Kol forest bend` next, and ended
  with no active path or runtime blockers. Explicit object-target actions still
  retain their destination-switch behavior. The user subsequently completed
  the combined Tantegel-to-Northern-Cave route manually and reported the
  connected system behaved as expected. Some older route segments still enter
  intermediate towns; treat that as a separate legacy-route polish task. The
  preserved post-run review state is World Map `(92,10)`, route
  `northern_cave`, next `Rain shrine east-shore detour`, path nil, and no
  runtime blockers.

- The second connected itinerary, `Tantegel -> Kol -> Swamp Cave`, is source-
  complete and live-verified in focused parts. From Tantegel `(43,43)`, loaded
  status reported `Current leg to Kol. Final destination: Swamp Cave`; the Kol
  trigger emitted `event=handoff route=swamp_cave waypoint=Kol forest west
  edge index=2 from_route=kol` and left no movement queued. Bare `U` retained
  the active Swamp Cave route even while an unrelated Travel object remained
  selected. After a natural Kol entry/exit cleaned the movement state, a fresh
  local Swamp Cave start at World Map `(104,10)` traversed the full established
  route: `(96,13)`, `(96,21)`, the x98 south-road detour, bridge lane
  `(92,37)`, x94 poison-swamp drop, row-41 lane, and entrance doorstep
  `(104,43)`. The final `DOWN` entered Swamp Cave map `0x15` at `(0,0)` and
  announced arrival. Final state was HP `149/149`, path nil, runtime blockers
  none, and no overworld route active. Two movement failures from force-seeded
  origins were rejected as teleport contamination and did not change map or
  route data. The user then manually completed the combined
  Tantegel-to-Swamp-Cave route. Fresh logs confirmed the staged Kol route start
  at frame `71501`, handoff at frame `84046`, and arrival at frame `89299`.
  Probe `SWAMP_MANUAL_ACCEPTANCE_20260813` at frame `92640` confirmed Swamp
  Cave map `0x15` `(0,0)`, HP `149/149`, no active path, no runtime blockers,
  and no active overworld route. This is the final player acceptance for the
  connected Swamp Cave route.

- Rain Shrine / Northern Cave first interior pass: map `0x0D` is a 10x10
  shrine with the wise man / old man at `(4,4)` and the live bottom
  entrance/exit at `(4,9)`. Route evidence toward the old man repeatedly
  bounced between `(4,7)` and `(5,7)` while trying to move north into `(4,6)`
  and `(5,6)`. Both target cells decode as tile `14` and model-walkable, but
  live movement proved the south approaches blocked-only: `(4,6).south`
  reached 20 blocked / 0 moved and `(5,6).south` reached 18 blocked / 0 moved.
  The next live pass found the same pattern farther west: `(3,6).south`
  reached 6 blocked / 0 moved and `(2,6).south` reached 4 blocked / 0 moved,
  while `(3,7)` and `(2,7)` had horizontal moved evidence. The follow-up route
  exposed the west face of the same hidden wall cluster: `(2,3).west` reached
  36 blocked / 0 moved and `(2,4).west` reached 37 blocked / 0 moved, with
  route-context hits also on `(2,5).west` and `(2,6).west`. Movement along
  column `x=1` stayed open, including repeated `(1,3)<->(1,4)` movement. These
  are now modeled as directional-only blockers. After the script reloaded,
  `report_runtime_blocks` was empty, confirming the permanent map patch is the
  active source of truth; `debug_pathfind_adjacent:4,4` from current `(4,1)`
  initially planned `2 south`, landing at `(4,3)` facing south, but live
  auto-walk proved that top approach wrong: `(4,2).north` reached 4 blocked /
  0 moved and the reroute also found `(3,2).north` at 3 blocked / 0 moved. The
  successful manual route went east along row 1, descended on the far east
  side, then came back west along row 4; those moved seams stay open. The
  current model treats `(3,2).north`, `(4,2).north`, `(5,2).north`, and
  `(6,2).north` as directional-only top-wall blocks. The return route toward
  the exit then exposed a mid-wall loop around `(6,5)`: raw
  `probe_edge_verify` confirmed `(5,5).east`, `(6,6).north`, and
  `(5,5).north` as blocked 5/5 each. After those were injected live, the next
  reroute also confirmed `(7,5).west` and `(7,5).north` as blocked 5/5 each.
  The next entrance-to-old-man route from `(4,9)` then confirmed
  `(6,6).south` and `(7,6).south` as blocked 5/5 each. These are all
  directional-only; the earlier `(6,4).west`, `(6,4).south`, `(6,5).north`,
  `(6,7).east/west`, `(7,4).west/east`, and `(7,7).west` moved seams stay
  open. Final noisy-cleanup verifiers promoted `(7,6).east`, `(5,3).east`,
  `(7,5).east`, `(7,9).north`, and `(6,9).north` after each confirmed blocked
  5/5. Follow-up Staff of Rain return-route cleanup superseded the earlier
  mixed raw verifier: from `(5,4)`, `(5,4)->UP` into `(5,3).south` blocked
  under same-origin route/probe evidence, then the reroute confirmed
  `(8,8)->DOWN` into `(8,9).north` the same way. With those runtime blockers,
  `auto_walk_blocker:4,9` reached the exit at `(4,9)` via row 8 and
  `(4,8)->DOWN`; the x=8 descent lane above row 9, row-8 westbound lane, and
  `(4,9).north` moved and stay open. Follow-up live testing reported both
  routes to and from the old man finishing smoothly. The chest is
  progression-gated until the old man receives what he is waiting for.

- The reverse route from Kol back to Tantegel now has its own connected
  variant. Before this patch, selecting the `Tantegel Castle` Travel landmark
  from near Kol could bind to the old Garinham/cave-road safety route and
  produce a huge direct west segment toward the cave road. Route starts now
  choose the closest matching castle variant from the current world-map
  position. From Kol, the castle route should first target `Kol forest west
  edge` `(96,13)`, then retrace the known Kol south-road and northeast-bridge
  waypoints before reconnecting at `Erdrick's Cave road` `(28,13)`.

- First Kol service-survey patch: the town exit is now the live south entry
  tile `(19,23)`, not the stale `(15,14)`. The decoder saw `(19,23)` and
  adjacent `(20,23)` as type-0 walls, but live movement proved them as
  passable entry/exit strip cells. A later pathability-filter repro from live
  `(18,23)` showed every object as unreachable until that west strip tile was
  also marked as a passthrough. The stopped parked survey also found a real
  loop near `Person 1`: from `(20,18)`, north into `(20,17)` blocked
  repeatedly and east into `(21,18)` blocked repeatedly. These are modeled as
  directional blocks only, preserving nearby passable seams. Reload Lua before
  rerunning the Kol survey; the automatic touch/probe did not appear to reload
  the active FCEUX script.

- Kol west-side NPC browsing is opening up after the service pass. The route to
  `Old Man 1` at object `(2,13)` looped between `(8,11)` and `(8,12)` while
  trying to enter `(7,11)` and `(7,12)` from the east. `(7,11).east` remains a
  narrow directional blocker, but `(7,12)` was later confirmed as the
  western-building Magic Key door cell opened from `(8,12)` facing west. Do not
  keep `(7,12).east` as a permanent blocker; the vertical connector between
  `(8,11)` and `(8,12)` stays open because it moved repeatedly.

- Kol Magic Key doors are now pinned from live verifier proof. `Western
  Building Door` is door cell `(7,12)`, opened from public stand `(8,12)`
  facing west. `West Side Door` is door cell `(1,14)`, opened from public stand
  `(2,14)` facing west. False candidates checked during the search were
  `(1,13)` from `(1,14)` facing up, `(1,3)` from `(1,4)` facing up, and
  `(1,4)` from `(2,4)` facing left; all produced no-door/no-key-delta results.

- Kol Merchant 1 autowalk keeps exposing narrow service-route wall bands, and
  the current model has been tightened from two live runs. The first run proved
  `(10,18).east` and `(10,19).east`. After a clean reload, the route advanced
  deeper, then proved `(11,20).north`, `(12,19).west`, `(16,21).east`,
  `(16,20).east`, `(16,19).east`, `(10,16).east`, `(10,16).north`,
  `(9,16).north`, `(8,16).north`, and `(7,15).east`. The final loop at
  `(8,15)` reached 45+ blocked observations on the last two seams before a
  small right tap broke the route and moved the hero to `(9,15)`. Reload Lua
  before retesting Merchant 1; the touch/probe path was consumed but did not
  refresh the log header. The next manual-reload retest confirmed the
  `stop_auto_walk` command works and exposed the next south-entry band toward
  adjacent goal `(11,21)`: `(12,19).north` and `(13,19).north` are the strong
  blockers, with lower-count directional evidence at `(15,19).north`,
  `(14,19).north`, and `(16,19).north`. Merchant 4 path testing later
  disproved the stale `(16,22).east` candidate, so the
  `(16,22)<->(17,22)` seam should stay open both ways.
  The follow-up touch/probe reload succeeded with a fresh `Started:
  2026-05-15 13:29:38` log header and position `(12,18)`, so this blocker
  batch is live. A read-only path preview from `(12,18)` to the current
  Merchant 1 target at `(11,21)` now returns no path even with NPCs skipped,
  so this likely needs service/interaction-tile decoding rather than another
  blind autowalk retry to that live target. The user then selected/teleported
  to `npc_7` / `Merchant 1`, and TALK proved he is a dialogue-only
  southern-island/Rimuldar hint NPC. He now stays in NPC browsing but is
  excluded from Services. `report_door_state` at position `(12,21)` showed
  `keys=0` and no opened-door RAM slots, so do not claim a confirmed door
  coordinate for him yet.

- Kol Merchant 2 is the Inn. Selected teleport placed the hero at `(19,2)`
  facing south toward Merchant 2 at `(19,4)`, and TALK opened the 20 GOLD inn
  prompt. The route back from that Inn stand toward the town entrance looped
  between `(21,2)` and `(22,2)`, repeatedly trying to go south into row 3.
  `map_reader.lua` now blocks only the proven north approaches into `(21,3)`
  and `(22,3)`; row-2 movement stays open. After reload, the next loop advanced
  to the east wall and repeatedly tried to enter `(23,1)` and `(23,2)` from the
  west. Those west approaches are now blocked directionally too. The next pass
  drifted one tile west, recovered, then found `(10,4).north` and
  `(11,3).west`; `(10,3).north` moved on retry and stays open. After another
  reload, Inn-to-exit completed. The reverse route from town entrance back to
  Inn then got close and looped between `(21,4)` and `(22,4)`, repeatedly
  trying to enter `(21,3)` and `(22,3)` from the south. Those south approaches
  are now blocked directionally too; the side seams on row 4 moved repeatedly
  and stay open. The next entrance-to-Inn retest looped across row 4 and proved
  `(23,3).south` plus `(20,4).east`, both `blocked=36 moved=0`. Those are now
  directional blockers; row-4 movement through `(21,4)`, `(22,4)`, and
  `(23,4)` stays open. The next retest routed farther west and looped around
  `(11,5)`, `(12,5)`, and `(12,4)`, proving `(11,4).south` and `(11,4).east`.
  Those are now directional blockers; nearby connector seams moved repeatedly
  and low-count row-5 hits remain diagnostic. A later working round trip still
  rerouted noisily. Cleanup now also models `(10,4).south` and `(9,2).south`
  from the success log, plus repeated low-count reroute seams `(11,3).north`,
  `(19,17).south`, and `(18,17).south`. Noisy/moved seams such as
  `(10,3).west` and `(18,18).east` stay open. Retest entrance-to-Inn after Lua
  reload.

- Kol Merchant 3 is live-confirmed as the weapon/armor shop. Selected teleport
  to `npc_13` / `Merchant 3` held the target at `(22,12)`, landed at `(20,12)`,
  and faced east. TALK opened the buy list, and the merchant reader spoke the
  live inventory: Copper Sword 180 G, Hand Axe 560 G, Half Plate 1000 G, Full
  Plate 3000 G, and Small Shield 90 G. `objects.lua` now labels him
  `Weapons Merchant` and routes through `(20,12)` facing east.

- Kol Merchant 4 is live-confirmed as the item/tool shop. Selected teleport to
  `npc_15` / `Merchant 4` held the target at `(14,21)`, landed at `(12,21)`,
  and faced east. TALK opened the buy list, and the merchant reader spoke Herb
  24 G, Torch 8 G, Dragon's Scale 20 G, and Wings 70 G. `objects.lua` still
  labels him `Tool Merchant`. A public-route polish pass promoted the real
  blocker band around the attempted east-side route: `(16,22).east`,
  `(1..4,10).north`, `(4,10..13).east`, `(7,9).west`, and
  `(7,13).east/west`; TALK checks from `(17,22)` and `(17,21)` facing west
  both returned "There is no one there." The missing public throat was found
  later on the west side: manual movement from `(1,16)->DOWN` reaches `(1,17)`,
  which ROM-decodes as tile-0/non-walkable, and route planning from `(1,17)`
  restores the Tool Merchant path to `(12,21)`. `map_reader.lua` now models
  `(1,17)` as a Kol passthrough. A clean-restore frontier pass then found the
  entrance-side connector: `(5,14)` also decodes as tile-0, but a normal walk
  to `(5,13)` followed by same-origin `probe_edge:DOWN` moved through `(5,14)`
  and settled at `(5,15)`. After reload, the planner found the standable
  `(1,19)` pocket; same-origin probes proved its east, south, and north exits
  blocked, so those false exits are now modeled as narrow directional blockers.
  Reload `main.lua` in FCEUX before validating the live route from the town
  entrance.

- FCEUX stale-Alt remains a polishing issue, separate from dialogue state.
  Logs show `keys=LeftAlt`, `joy1=-`, and an empty external bridge while idle;
  movement or a real key clears it temporarily, then idle can re-trigger the
  warning. Treat this as an input-bridge/focus quirk, not a route or dialogue
  blocker.

- Overworld landmarks are now hooked into the same-map teleport system in the
  worktree. On the world map, selected Travel landmarks can use exact
  selected-object teleport, and debug builds also accept
  `teleport_landmark:NAME` / `teleport_overworld:NAME` for named destinations
  such as `Garinham`, `Brecconary`, or `Tantegel Castle`. The command refuses
  off-map use and uses the normal teleport guards. Live validation after the
  user's Garinham error: named teleport to `Garinham` landed on world-map
  `(1,2)`, and selected-object `teleport_selected` on the `Garinham` Travel
  object logged `landing_reason=overworld_travel` / `ok=true`.

- Selected-object teleport is safer for talking to hard-to-reach NPCs. The
  live Garinham repro landed beside `Woman 2`, but the NPC wandered before
  TALK, so the old one-frame face tap still produced `There is no one there.`
  Teleport now briefly pins the selected NPC's live target tile, faces the
  target for 4 frames, and skips heavy text/menu scans for 45 frames after the
  RAM jump. The selected-NPC hold now has its own shorter 600-frame window,
  uses diff-only RAM writes, and releases as soon as TALK dialogue opens or
  misses. Validation used `teleport_selected` on Garinham `Woman 2`, then TALK
  reached `Welcome to Garinham. May thy stay be a peaceful one.` Follow-up
  profiling showed the target hold itself is cheap; the remaining lag was
  mainly steady text/menu scanning, so idle scanner cadence was throttled while
  preserving faster checks during input/menu/dialogue. Final player state after
  cleanup: `map=0x09(Garinham) x=15 y=14`, menu closed.

- Garinham public-service pass is done for now. Public routing is good enough
  for normal play to continue: Tool Merchant, Inn, Weapons Merchant, town
  exit/entrance, and the grey-building grave-route door are modeled. The town-side
  exit object no longer targets the `(15,14)` corridor; it now uses the west
  entry boundary `(0,14)` with interaction stand `(1,14)` facing west. The
  overworld Garinham landmark also moved west from `(2,2)` to `(1,2)`, leaving
  `(2,2)` as the approach corridor that points `1 west` to town. Circle back
  for locked chests, Garin's Grave B1, and any remaining hidden/dialogue-only
  NPCs.

- Garinham has been reached in live play. Current confirmed entry state:
  `map=0x09(Garinham) x=0 y=14`. The guide/image pass is staged at
  `project_resources/maps/garinham/`: local image
  `realmofdarkness_garinham.png`, with a text transcription in `README.md`.
  Early public-service priorities are the exit, inn, item shop, and
  weapon/armor shop. Guide data says the inn costs 25 G; the item shop sells
  Herb, Torch, and Dragon's Scale; the weapon/armor shop sells Club, Copper
  Sword, Hand Axe / Iron Axe, Leather Armor, Chain Mail, Half Plate, and Large
  Shield / Iron Shield. The large grey/north building is Magic-Key/later
  content. Its visible chests are 10-17 G, Torch, and Herb; Garin's Grave
  entrance is hidden through the building's dark back-wall path. The internal
  locked-door guards are not progression-critical according to StrategyWiki.
  First service pass: Garinham `Merchant 2` is live-confirmed as the item/tool
  shop via the Herb, Torch, and Dragon's Scale menu, and is now labeled `Tool
  Merchant` in Services. The attempted autowalk back from that shop stalled at
  `(3,11)`, repeatedly testing `(3,12)` and `(4,11)`. A reload stopped the loop
  cleanly; current live checks show no runtime blocks and no active path. The
  user manually checked `(3,11)`: north and west are open, while south and east
  are engine-blocked. `map_reader.lua` now closes `(3,12).north` and
  `(4,11).west` directionally. Post-reload `inspect_move` confirmed down/right
  are now modeled blocked and up/left remain passable. Retry the return route
  from the Tool Merchant next. The next exit autowalk no longer hit those two
  exact edges, but wandered around the same building pocket. Raw verifiers now
  confirm three more blocked seams from that loop: `(2,12)->RIGHT` into
  `(3,12)`, `(3,10)->RIGHT` into `(4,10)`, and `(3,10)->UP` into `(3,9)` each
  blocked 5/5 with `classification=confirmed_blocked`. Those are now modeled
  as `(3,12).west`, `(4,10).west`, and `(3,9).south`. A fresh debug path from
  `(3,10)` to the exit now starts west/north instead of cycling through the
  blocked east entries. The follow-up route then found a second loop from
  `(2,10)`: `(3,10)->LEFT` was noisy but passable after seam retry, while
  `(2,10)->UP` into `(2,9)` and `(2,10)->LEFT` into `(1,10)` both verified
  blocked 5/5. These are now modeled as `(2,9).south` and `(1,10).east`.
  Another live loop confirmed the user's note that `(2,10)<->(3,10)` remains
  passable despite the bump sound, then verified `(2,11)->LEFT` and
  `(2,12)->LEFT` blocked 5/5; these are now `(1,11).east` and
  `(1,12).east`. The planner's resulting no-path state exposed a decoder gap:
  `(2,13)` is type-2/non-walkable in the static grid, but
  `probe_edge_verify:2,12,DOWN,5` moved into it 5/5. It is now a Garinham
  passthrough cell, and the live planner from `(2,13)` reaches the exit target
  with `1 south, 13 east`.
  The reverse trip from entrance back to the Tool Merchant then bounced near
  the x=7 lane. Clean verifiers promoted `(6,10).east`, `(6,11).east`, and
  `(6,12).east` after `(7,10)->LEFT`, `(7,11)->LEFT`, and `(7,12)->LEFT` each
  blocked 5/5. After reload, the entrance/exit tile `(15,14)` plans to
  Merchant 2's stand with `1 north, 9 west, 3 north, 2 west`, facing west from
  `(4,10)`. The replacement route's critical seams through `(6,13)`,
  `(6,12)`, `(6,11)`, `(6,10)`, `(5,10)`, and `(4,10)` all moved 5/5 in raw
  verification.
  Drift follow-up showed the remaining reroutes on both successful Tool
  Merchant routes were execution overshoot rather than new map geometry. The
  exit route drifted one extra tile during turn settle at `(10,10)->(11,10)`,
  `(12,11)->(12,12)`, and `(13,13)->(13,14)`; the entrance-to-tool route did
  the same at `(7,13)->(6,13)`. Suspect seams were timing-noisy but passable
  after brute-force retry, so no new Garinham blockers were promoted from that
  evidence. `auto_step.lua` now releases queued early-twitch movement before a
  route turn while keeping straightaway early-twitch holding. User retest says
  both Tool Merchant routes are usable now, each with one remaining drift
  reroute; defer that drift to polishing unless it begins causing route
  failures.
  Next service pass: Garinham `Merchant 4` is live-confirmed as the
  weapon/armor shop. Selection landed at public stand `(10,16)`, facing south
  toward target `(10,18)`, and TALK opened the shop menu: Club 60 G, Copper
  Sword 180 G, Hand Axe 560 G, Leather Armor 70 G, Chain Mail 300 G, Half
  Plate 1000 G, and Large Shield 800 G. `objects.lua` now labels him
  `Weapons Merchant` and uses `(10,16)` facing south as the interaction stand.
  Return-route noise from the Weapons Merchant stand exposed two more
  Garinham engine blockers: `(10,16)->RIGHT` into `(11,16)` and
  `(13,14)->RIGHT` into `(14,14)`. Both verified blocked 5/5 with raw holds and
  are now modeled as `(11,16).west` and `(14,14).west`. After reload, the
  planner chose `1 north, 4 east, 1 north, 1 east` from `(10,16)` to the exit,
  and `validate_path` walked all 7 steps with 0 mismatches.
  The return-to-merchant direction then exposed the other side of the same
  counter throat. Raw verifiers blocked 5/5 on `(12,15)->LEFT`,
  `(12,16)->LEFT`, `(12,15)->DOWN`, `(15,14)->LEFT`, `(15,16)->LEFT`,
  `(15,15)->LEFT`, and `(14,13)->DOWN`, now modeled as directional blockers.
  The mixed `(15,13)->LEFT` seam stays open because validation crossed it on
  retry. The current validated entrance-to-Weapons-Merchant route from
  `(15,14)` is `1 north, 3 west, 1 south, 2 west, 2 south`, and
  `validate_path` walked all 9 steps with 0 mismatches.
  Follow-up on the viable round trip found no drift-reroute log entries, but
  raw verifiers confirmed two remaining seam bumps as real blockers:
  `(10,15)->RIGHT` into `(11,15)` and `(13,15)->RIGHT` into `(14,15)` both
  blocked 5/5, now modeled as `(11,15).west` and `(14,15).west`. A suspicious
  `(15,17)->LEFT` bump was only timing noise; the raw verifier moved into
  `(14,17)` 5/5, so keep that seam open.
  The inn is now confirmed too: Garinham `Merchant 3` at `(17,15)` opens
  `Welcome to the traveler's Inn. Room and board is 25 GOLD per night...` from
  public stand `(15,15)` facing east. `objects.lua` now labels him `Inn` and
  keeps him in Services.
  The old Garinham east-door guess at `(19,16)` was later disproved with Magic
  Key access: OPEN from `(19,17)` facing north reported `There is no door here`.
  The grey-building grave-route door is now modeled at door cell `(17,10)` as
  `Grave Route Door`, opened from `(17,9)` while facing south; fresh
  `DOOR_STATE` recorded slot `0=(17,10)`.
  Manual movement may share the same timing root: the user reported some
  ordinary taps do not move while others overshoot. The manual wall-bump fixes
  were probably too eager to release physical tap-to-step input on open floor,
  so released `manual_tap` now gets a short extra hold after an early movement
  twitch (`auto_step_manual_early_hold_frames=8`) before it releases and, if no
  tile move follows, silently cancels as before. User retest says manual
  movement is working better; try it on the overworld next, but Garinham's Tool
  Merchant is no longer an active blocker.

- Tantegel Castle Sage service: the user manually confirmed Old Man 2 restores
  MP, and external guide/map notes agree that the castle wise man restores MP.
  `objects.lua` now labels the NPC at `(20,26)` as `Sage` and includes him in
  Services. The usable interaction stand is not adjacent to the NPC: live TALK
  proof from `(18,26)` facing east opened Sage dialogue, and post-reload
  Services output now says `Sage: 2 east, counter here ... obj 20,26 interact
  18,26`. From `(12,29)`, the locator describes that stand as `counter 3
  north, 6 east`. The route is NPC-sensitive but now good enough for play: after
  the `(20,20)` correction below, the user confirmed a successful
  entrance-to-Sage route, and the return route can also open when live NPCs are
  not in the way. The stale full-block override was corrected after raw probes
  showed
  `(20,20)` is standable and open north/south/west, while `(20,20)->RIGHT`
  into `(21,20)` is blocked one-way. After reload, `(20,20)` inspects as
  passable, `(20,20)->RIGHT` inspects as directionally blocked, and
  `(21,20)->LEFT` remains passable. From the Sage stand,
  `debug_pathfind_adjacent:11,29` now finds a 37-step route to the
  exit-adjacent tile; skip-NPC path debug finds a 29-step route.
  Raw verifier proof still supports keeping the south-gate blockers
  `(16,29)->UP`,
  `(17,29)->UP`, `(18,29)->UP`, `(19,29)->UP`, and `(19,29)->RIGHT` closed. Do
  not reopen those confirmed south-gate seams just to force shorter routes.
  Guide cross-checks point away from the Sage being locked-door-gated: the
  locked-door notes are for the Magic Key shop and Stones of Sunlight route,
  while the MP-restoring old man is described as a main-floor service. The user
  also found `(18,27)->DOWN` blocked; `probe_edge_verify:18,27,DOWN,5`
  confirmed 5/5 blocked into `(18,28)`, so that north approach is now modeled
  as a directional blocker. This was part of the Sage-route cleanup rather than
  a locked-door-gating issue.
  Additional verifier checks found `(17,27)->DOWN` blocked 5/5 and it is now
  modeled as `(17,28).north`; `(17,27)->LEFT` blocked 5/5 but was already
  covered by `(16,27)` being a full blocked-cell override. A first
  `(18,27)->RIGHT` verifier had looked passable, but the later clean-state
  recheck matched the user's manual observation: two fresh verifier runs stayed
  blocked 5/5, so `(19,27).west` is now modeled too. After reload,
  `inspect_move:17,27,DOWN` and `inspect_move:18,27,RIGHT` both report their
  new directional blockers as effective.
  The same follow-up confirmed `(18,26)->RIGHT` into `(19,26)` blocked 5/5 twice
  with clean menu/input state, so `(19,26).west` is now modeled; after reload,
  `inspect_move:18,26,RIGHT` reports the blocker as effective.
  The next reroute exposed `(18,25)->RIGHT` into `(19,25)`, which also verified
  blocked 5/5 twice. `(19,25).west` is now modeled; after reload,
  `inspect_move:18,25,RIGHT` reports the blocker as effective. The later
  `(20,20)` correction supersedes the old Sage-stand-to-exit no-path result,
  and the user later confirmed the entrance-side Sage route can succeed when
  live NPC traffic cooperates.
  Castle entrance to `Stairs Up to Tantegel Castle Throne Room` was noisy
  because the planner tried false north entries from `(12,29)` and `(13,29)`;
  both verified blocked 5/5 and are now modeled as `(12,28).south` and
  `(13,28).south`. Current evidence does not show a working public route from
  the south entrance side to that return stair; after the false entries are
  closed, post-reload path debug from `(12,29)` reports clean `No path found`
  instead of a noisy autowalk failure.
  Merchant cleanup: the user confirmed Tantegel Castle Merchants 1 and 2 only
  offer dialogue, so they remain browsable as NPCs but are removed from
  Services. Merchant 3 sells Magic Keys and is now labeled `Magic Key Merchant`
  in Services. Follow-up research confirmed Merchant 3 cannot be accessed yet,
  likely because the route is locked-door gated; wait until keys/doors are in
  play before treating a failed route to him as missing map data. With the Sage
  and public services handled, Tantegel Castle is clean enough to leave for now
  and the next playtest focus is the next town.

- Strategic map-completion pivot after Merchant 4: stop treating perfect map
  truth as the immediate bar. For the next maps, first establish reliable
  routes to merchants, inns, exits, stairs, locked doors, chests, and other
  essential services. Defer unreachable dialogue-only NPCs to the polishing
  phase unless they offer a progression clue or required gameplay hint.

- Brecconary is service-complete for now. The user manually tested all
  essential services, and routes both to and from the town entrance pass in
  normal play. The remaining unreachable NPCs were manually checked; a couple
  give clues, but none are required for progression. Keep them for the
  polishing phase unless later game logic proves one of those clues is required.
  Next playtest focus is the first castle / Tantegel area, specifically the
  guide-mentioned sage who may restore MP.

- Brecconary service cleanup: Merchant 1 is dialogue-only and has been removed
  from the Services filter while staying available as a normal NPC. The current
  confirmed services are `Weapons Merchant`, `Inn`, `Tool Merchant`,
  `Fairy Water Merchant`, and `Curse Remover`. Woman 1 is the Fairy Water
  merchant behind the northeast door. Old Man 2 claims to remove curses; accept
  that service label for now, with a later polish check when the hero is
  actually cursed. The Old Man 2 route is now solved: manual movement and live
  logs proved `(24,13)->UP` into `(24,12)`, `(24,12)->UP` into `(24,11)`, and
  `(24,11)->DOWN` back into `(24,12)`. `map_reader.lua` promotes `(24,12)` as a
  passthrough and leaves the `(24,11)<->(24,12)` seam open. After reload,
  `debug_pathfind_adjacent:24,10` from the entrance `(1,15)` routes to
  `(24,11)` in 29 steps and faces north; `debug_pathfind_to:1,15` from
  `(24,11)` also returns in 29 steps. Runtime blockers stayed empty. This
  solves Curse Remover. Tool Merchant route testing then found two stale route
  edges: `(16,25)->RIGHT` into `(17,25)` blocks, and `(22,26)->LEFT` into
  `(21,26)` blocks. The replacement bridge is the long row-22 corridor:
  `(17,22)` is now confirmed passable from both east and west, so the entrance
  routes to the Tool Merchant public stand again, and the stand routes back to
  the entrance after live NPC clutter clears.

- Autowalk no-path speech should stay cautious around stationary NPCs. Current
  Brecconary logs show `NO_PATH_STATIONARY_NPC` for the exit route, followed a
  few seconds later by a tryable route after NPC state changed. The
  player-facing hint now says the route may be blocked by a stationary or
  out-of-date NPC position and suggests retrying, instead of claiming waiting
  cannot clear the route.

- Object browsing now avoids full NPC-list rebuilds on plain browse/readout
  keys under BizHawk. The first moving-NPC fix made Person 1 and other moving
  NPCs track again, but calling `objects.update_npcs()` on `J`/`K`/`L` brought
  back a 1.5-2 second emulator/audio freeze between object-browser presses.
  `objects.describe_current()` now reads only the selected NPC slot live for
  spoken direction/distance, while `J`/`K`/`L`, filter readouts, and
  command-file object browsing skip the full rebuild. Route/planning actions
  (`R`, `O`, `U`, `pathfind`, `auto_walk`) and explicit pathability refreshes
  still refresh the full NPC list before planning. Live command-file browse
  proof after reload produced object descriptions with no `CMD_TIMING` warning;
  the user's focused physical `J`/`L` retest confirmed this brought the delay
  down to a fraction of a second between hops. Treat this as a successful first
  tuning pass unless the remaining small pause becomes a normal-play problem.

- Player-facing selected-object teleport should no longer refuse common
  non-NPC targets just because the object tile itself is not standable. The
  latest log showed `Shift+Enter` on Brecconary's `Exit to World Map` trying to
  land on `(0,15)` and refusing as not walkable. Exact selected-object teleport
  now asks the object resolver for all object types: walkable objects such as
  stairs still land exactly, while blocked exits/doors/chests land on a nearby
  usable cell and face back toward the object.

- Brecconary Merchant 4 public access update: the user found a small walkable
  pocket at `(22,25)`/`(23,25)`. Fresh live evidence at `map=0x08` confirmed
  the player at `(23,25)` with no runtime blockers, `(22,25)<->(23,25)` as
  passable, `(23,25)->RIGHT` into `(24,25)` as directionally blocked, and TALK
  from `(23,25)` facing east opening the tool shop (`MERCHANT_ACTION:
  Merchant. Buy.`). This supersedes the earlier conclusion that Merchant 4 was
  isolated: route the service to `(23,25)` facing east, but keep the movement
  seam into `(24,25)` blocked.

- Brecconary Merchant 4 public route recovery: the older `(17,25)` bridge is
  no longer trusted as an entrance route. Fresh live route testing repeatedly
  blocked `(16,25)->RIGHT` into `(17,25)`, and a raw
  `probe_edge_verify:RIGHT,3` from `(16,25)` confirmed `moved=0 blocked=3`
  with `reason=raw_hold_timeout`. `map_reader.lua` still treats `(17,25)` as a
  standable passthrough for other approach checks, but now blocks its west
  approach. The replacement bridge is `(17,22)`: manual movement and raw
  verifier proof crossed `(16,22)->RIGHT` and `(18,22)->LEFT` into `(17,22)`
  3/3 times from each side. After reload, `debug_pathfind_to:23,25` from
  `(1,15)` reports a 38-step path to the Tool Merchant public stand.

- Brecconary Merchant 4 return route regression: the older `(21,26)`
  passthrough evidence is now stale for the east approach. Current live route
  execution from `(22,26)->LEFT`, seam retries, and manual taps all blocked
  into `(21,26)`, ending with `blocked=13 moved=0` for `cell=(21,26)
  approach=east`. `map_reader.lua` still treats `(21,26)` as standable for
  other approach checks, but now blocks `(21,26).east`. Live reload proof:
  `inspect_move:22,26,LEFT` reports `directional_blocked=true` and
  `effective_passable=false`. The row-22 bridge now supplies the return route:
  from `(23,25)`, the first reverse debug path was blocked by live NPC clutter
  at `(12,20)`/`(20,23)`, and a retry after unfreezing NPCs found a 36-step
  route back to `(1,15)`.

- Merchant 4 route drift follow-up: the latest manual drifts were route-settle
  overshoots, not missing passability data. The auto-walk reached open-floor
  turn transitions, then slid one tile off the queued path before the next
  planned direction started. `route_manager.lua` now catches
  `route_drift_off_path`, replans from the drifted tile to the same selected
  object, and logs `AUTO_WALK_DRIFT_REROUTE`. Live proof showed the recovery
  surviving several drifts on a Guard 2 route and still reaching the target.
  User testing later confirmed the entrance-to-Merchant 4 route can succeed
  after reroutes in that older map state; current Tool Merchant routing now
  uses the `(17,22)` row-22 bridge instead of the stale `(17,25)` or `(21,26)`
  seams.

- Brecconary Merchant 4 noise-hardening pass: the current live map is
  confirmed as `map=0x08(Brecconary)`, not castle data. `(27,25)->DOWN` into
  `(27,26)` is a confirmed false-wall passthrough: verifier movement succeeded
  3/3, with six moved observations total, and post-reload
  `inspect_move:27,25,DOWN` reports `effective_passable=true`. The lower-right
  bypass that A* invented after this was false: validation failed at
  `(28,27)->DOWN`, and a direct check blocked the same edge, so `(28,28).north`
  is now modeled as a directional block. The remaining clean no-path from
  `(27,25)` to Merchant 4's stand `(25,26)` is currently caused by live NPC
  occupancy around `(27,27)/(27,28)`, not by a new map blocker. A parked-NPC
  survey then reproduced the timing-noise problem by treating the confirmed
  passable `(27,26)` edge as blocked during auto-step retries, so
  `route_manager.lua` now keeps blocked-only seam memory diagnostic-only; only
  explicit manual commands such as `add_blocked_edge` promote runtime blockers.
  Follow-up manual testing found another public-route frontier seam:
  `(22,25)->LEFT` into `(21,25)` is hard engine-blocked. Pre-patch
  `inspect_move:22,25,LEFT` said `effective_passable=true`, so
  `map_reader.lua` now models `(21,25).east` directionally for Brecconary.
  The next planned route from live `(23,22)` exposed `(23,22)->DOWN` into
  `(23,23)`: validation could not move through it, and the user manually
  confirmed the engine definitely blocks it. `map_reader.lua` now models
  `(23,23).north` directionally. The validation tool itself was hardened to
  stop duplicate injected steps and to cancel active auto-step state on abort,
  which prevents post-abort seam noise from being written. It also uses a
  validation-only forced D-pad release after injected validation arrivals, so
  normal manual-cancel behavior stays intact. Final live reload from `(25,22)`
  reported no path to `(25,26)` with runtime blockers still empty.
  Follow-up manual cluster check found the vertical x=22 approach open through
  `(22,26)`'s north edge: `(22,21)` is open from the south, `(22,22)` through
  `(22,25)` are open north-to-south, and only the south exit from `(22,26)` is
  closed. East/west on those cells was not checked. The live model already
  matches this, so this pass added regression coverage rather than new blocker
  data. A validation pass then reached `(25,22)` cleanly and failed on
  `(25,22)->DOWN` into `(25,23)`; the user manually confirmed that edge is
  actually open from north to south, so that failure is treated as validation
  noise and `(25,23).north` is pinned open. A follow-up validation then reached
  `(27,28)` and failed on `(27,28)->LEFT` into `(26,28)`; live inspect still
  said that edge was passable, but repeated manual taps also blocked there and
  the user confirmed it is engine-blocked. `map_reader.lua` now models
  `(26,28).east` directionally, leaving other approaches to `(26,28)` open for
  future checks. Reload proof showed `inspect_move:27,28,LEFT` now blocked by
  the model with runtime blockers empty. The next generated detour failed
  immediately on `(27,28)->DOWN` into `(27,29)` even though static inspect still
  said that down edge is passable. Repeated manual down taps also blocked
  there, and the user confirmed the south exit is engine-blocked. `map_reader.lua`
  now models `(27,29).north` directionally too. Reload proof showed
  `inspect_move:27,28,DOWN` now blocked by the model with runtime blockers
  empty. The next generated detour failed immediately on `(27,28)->RIGHT` into
  `(28,28)` while static inspect still said that right edge was passable.
  Repeated manual right taps also blocked there, and the user confirmed the
  east exit is engine-blocked. `map_reader.lua` now models `(28,28).west`
  alongside the existing `(28,28).north` block. Reload proof showed
  `inspect_move:27,28,RIGHT` now blocked by the model with runtime blockers
  empty, and from live `(27,28)` the route to Merchant 4's interaction tile
  `(25,26)` now reports clean no-path (`visited=52`).
- Manual wall-bump responsiveness follow-up: Brecconary logs showed physical
  wall bumps producing `manual_tap` auto-step timeouts after 45 frames, which
  can make real collisions feel much worse than a normal held-key bump. The fix
  keeps manual movement from adding a synthetic tap-to-step hold when the target
  edge is already a known static permanent or directional blocker. The player
  can still deliberately hold a direction into a wall, and debug/probe injected
  steps can still test known blockers, but quick released taps into known walls
  now stop at `AUTO_STEP_REFUSED_STATIC_BLOCK` instead of writing another seam
  observation. Live reload proof: `LAUNCHER_PROBE:
  codex_static_wall_refusal_reload` at `map=0x08(Brecconary) x=24 y=25`.
  Follow-up logs showed the same post-release hang still happened on unmodeled
  wall/NPC collisions from `(24,25)`, so physical `manual_tap` now releases the
  synthetic D-pad as soon as the movement subpixel twitches instead of holding
  into the obstruction until timeout. Debug/probe injected steps and queued
  route verification still keep the more conservative early-twitch behavior.
  Reload proof: `LAUNCHER_PROBE: codex_manual_tap_release_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
  One more log pass showed why this still felt bad: the turn-repress recovery
  rearmed the same direction after the release, then held it into the wall/NPC
  until timeout. Physical `manual_tap` now also suppresses that re-press after
  any movement-subpixel twitch; debug/probe injection and queued routes keep
  their conservative re-press behavior. Reload proof:
  `LAUNCHER_PROBE: codex_manual_repress_suppressed_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
  The user's half-second timing clue then matched the remaining log path:
  released physical bumps were still reaching the normal 45-frame blocked-step
  publication, which writes seam/NPC block evidence. Physical `manual_tap` now
  silently cancels about 20 frames after a twitch if the tile has not changed,
  so normal released wall bumps do not publish blocked seam events. Reload
  proof: `LAUNCHER_PROBE: codex_manual_twitch_silent_cancel_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
- Brecconary weapon-shop throat and blocker-policy follow-up: manual movement
  proved `(5,7)<->(5,6)` is open both ways, matching the earlier manual
  proof that `(5,7)<->(5,8)` is open. `map_reader.lua` no longer models
  `(5,6).south` or `(5,8).north`; the remaining local modeled wall is the
  east edge into `(6,7)`. Fresh live reload
  `LAUNCHER_PROBE: codex_manual_promotion_reload` plus `inspect_move:5,7,UP`
  reported `effective_passable=true` with no directional blocker. A hostile
  verifier repro still reported `probe_edge_verify:5,7,UP,3` as
  `confirmed_blocked`, but the new policy correctly kept
  `runtime_added=false`, logged `manual_promotion_required=true`, and left
  `RUNTIME_BLOCKS map=0x08 none`. Treat verifier consensus as suspect
  evidence only; use `add_blocked_edge:X,Y,DIR` or `add_blocked_tile:X,Y`
  only after manual review.
- Previous Brecconary Merchant 4 alternate-pocket check: the user manually verified
  `Merchant 4` is the normal tool merchant. The raw trigger at `(24,25)`
  opens the tool shop while facing east, but it is not public floor:
  `(24,25)->LEFT` and `(23,25)->RIGHT` both blocked 5/5. The then-confirmed
  alternate interaction tile is
  `(25,26)` facing north: `(25,27)->UP` moved into `(25,26)` 3/3 despite a type-0
  decode, and TALK there opened the tool shop/item list. `map_reader.lua` still
  treats `(25,26)` as a passthrough, but later manual/live evidence superseded
  this as the normal service target: `objects.lua` now routes Merchant 4's
  service interaction to `(23,25)` facing east. The route from public origin
  `(1,15)` is still blocked, though: after reload, `debug_pathfind_to:25,26`
  and `debug_pathfind_to:25,27` both returned no path, and the remaining lower
  southeast frontier seams `(14,28)->RIGHT`, `(15,27)->DOWN`,
  `(15,27)->RIGHT`, and `(16,26)->DOWN` are all live-blocked. The boundary is
  one-way in places: `(16,27)->UP` and `(15,28)->LEFT` moved cleanly, and
  `(25,26)->DOWN` blocked 5/5 despite `(25,27)->UP` entering the stand. A later
  inside-out validation from `(25,27)` exposed two more false exits:
  `(25,27)->LEFT` into `(24,27)` and `(25,27)->DOWN` into `(25,28)` both
  blocked 5/5. With those modeled, `(25,27)` can no longer path back to public
  space (`visited=2`), and public origin `(1,15)` still cannot path to the
  tool-shop interaction tile `(25,26)` (`visited=406`) with no runtime blocks.
  A later public-route attempt reached `(22,26)`, but the user manually
  verified `(22,26)->DOWN` into `(22,27)` is hard engine-blocked; model that as
  `(22,27).north`, not a full-cell blocker. This no longer means Merchant 4 is
  globally isolated; it only means the older `(25,26)` alternate pocket has no
  public route. A
  follow-up suspect-cell pass found no safe route-opening patch: `(26,25)` and
  `(26,27)` blocked 5/5, `(23,27)` blocked from `(23,26)`, and the potential
  false-wall cells `(23,26)`, `(24,26)`, and `(27,26)` produced passable or
  mixed evidence without forming a reliable connector to `(25,26)`. Runtime
  blocks stayed empty, so leave these as manual-check candidates for now.
- Brecconary Merchant 4 tool-shop item-list speech is fixed. The open list
  showed `Herb 24`, `Torch 8`, and split `Dragon's 20` / `Scale`, but the
  merchant detector reported `offers=""` because its catalog only included
  equipment names. The shop catalog now includes normal item-shop goods, so the
  live open list reports `offers="Herb, Torch, Dragon's Scale"` and speaks
  `Herb. 24 gold.`, `Torch. 8 gold.`, and `Dragon's Scale. 20 gold.` as the
  cursor moves.
- Brecconary Merchant 4 Buy/Sell prompt speech is fixed. The first shop prompt
  shows `BUY` and `SELL` over stale command-menu rows, so the field command
  reader mislabels D9 `0`/`1` as `TALK`/`STATUS`. The merchant reader now has
  an action mode for `What can I do for thee?`: D9 `0` speaks `Buy`, D9 `1`
  speaks `Sell`, and cursor-blink row churn does not repeat the prompt.
- Brecconary Merchant 4 close-out dialogue overlap is fixed. While the merchant
  reader owns a shop prompt/list, `main.lua` now keeps the lower-dialogue
  baseline synchronized with the visible prompt. Closing the item list now
  speaks only `I will be waiting for thy next visit.` instead of dragging the
  prior welcome / `What dost thou want?` text back into the farewell.
- Brecconary inn west-room door correction: the old `(5,22)` model is a ghost.
  OPEN from `(6,22)` facing west reported `There is no door here`. The
  live-confirmed stand is `(6,23)` facing west; `verify_door_after` recorded
  `expected_door=(5,23)`, `expected_present=true`, key count `3 -> 2`, and
  opened-door RAM slot `0=(5,23)`. The old directional blocker on
  `(5,23).east` was really the closed inn door and should not remain as a
  permanent wall after the door opens. The follow-up route-out failure was a
  second decode issue: `(3,23)` is a type-0 false-wall bridge on the door
  side, but same-origin `(3,23)->WEST` into `(2,23)` blocks and is now modeled
  as `(2,23).east`. A later restored-route retest superseded the earlier noisy
  north-corridor read: autowalk from `(6,23)` blocked twice on `(8,23)->UP`,
  and a direct same-origin probe from `(8,23)` timed out with
  `blocked_despite_open_preview`, so `(8,22).south` remains a permanent
  directional block. The next walked verifier crossed `(6,21)->RIGHT` through
  `(7,21)`, so the older `(7,21).west` block was stale and should stay open.
  After `reload_navigation_modules`, `auto_walk_blocker:1,15` from `(8,21)`
  queued `4 north, 7 west, 2 north`, reached `(1,15)`, restored parked NPCs,
  and left no runtime blocks. The earlier `(8,11)->UP` passthrough through
  decoded wall `(8,10)` remains useful once a route reaches that corridor.
- Brecconary current door-attribution check: from the public origin `(1,15)`,
  with NPC blockers skipped and door RAM simulated, the known doors split the
  current live NPC table cleanly. `Northeast Door` `(21,6)` unlocks `Woman 1`;
  the user manually verified that `Woman 1` is the Fairy Water merchant, so
  this target is expected to be locked behind that door. `Inn West Room Door`
  `(5,23)` unlocks `Old Man 1` at his current `(1,20)` position and `Guard 4`.
  Opening both doors still does not route to
  `Weapons Merchant` stand `(5,6)`, the center-east room (`Person 3`,
  `Old Man 2`, `Guard 2`), the southeast room (`Person 1`, `Person 5`),
  `Guard 3`'s lower-left room, or `Merchant 4`'s southeast tool-shop region.
  Treat those as route/seam follow-ups rather than known-door-gated NPCs.
- Brecconary door/classification pass: Mike's RPG Center labels the services as
  inn, weapon/armor shop, item shop, Fairy Water/special item shop, and curse
  remover; Realm of Darkness and Gamer Corner note the Fairy Water shop needs a
  Magic Key, and Gamer Corner lists two Brecconary locked doors: northeast
  building and west room in the inn. The object locator previously exposed no
  doors on map `0x08`; it now exposes `Northeast Door` `(21,6)` and
  `Inn West Room Door` `(5,23)`, and `map_reader.lua` checks both through the
  opened-door RAM array. With both doors synthetically open in RAM, the
  earlier static pass made only `Guard 4` and `Woman 1` reachable; the current
  live-NPC refinement also puts `Old Man 1` behind the inn west-room door.
  `Weapons Merchant`, `Person 3`, `Person 5`, `Old Man 2`, `Merchant 4`, and
  `Person 1` remain no-path, with current live additions `Guard 2` and
  `Guard 3`, so they are missing route/blocker-data follow-ups rather than
  known door-gated targets. Older direct verifier evidence that said
  `(5,7)->(5,6)` was blocked is now considered timing-noise evidence, not a
  map fact; manual movement and static inspect show the weapon-shop stand seam
  is open.
  Closed-door no-path hints are now target-aware: opening the reachable door
  frontier must actually make the selected object reachable before the player
  hears the magic-key/door advice.
- Brecconary false-blocker poke-around: a follow-up topology pass showed that
  opening one of `(20,12)/(21,12)/(22,12)/(24,12)` would connect the
  Person 3 / Old Man 2 room in the model, while southeast bridge candidates
  would connect `Person 5`, `Person 1`, or `Merchant 4`. Live verifier probes
  blocked all checked candidates, including `(24,13)->UP`, `(21,8)->DOWN`,
  `(17,10)->RIGHT`, `(21,16)->DOWN`, `(25,14)->DOWN`, `(17,20)->DOWN`,
  `(16,25)->RIGHT`, `(16,26)->RIGHT`, `(14,28)->RIGHT`,
  `(15,27)->DOWN`, `(15,27)->RIGHT`, `(22,13)->UP`, `(21,13)->UP`,
  `(20,13)->UP`, `(19,13)->UP`, and `(16,22)->RIGHT`. Runtime blocks were
  cleared after each verifier pass, and the player was restored to `(1,15)`.
  This was later resolved in two places: `(24,12)` is the intended passthrough
  into the Old Man 2 room, and the old `(16,22)->RIGHT` block was superseded
  by raw verifier proof that `(17,22)` is passable from both east and west.
- Selected-object NPC teleport follow-up: while checking Brecconary NPCs before
  leaving town, `Shift+Enter` was found to teleport onto the selected NPC's
  occupied tile. The hotkey now resolves an NPC landing first: service NPCs use
  their interaction stand when one is modeled, otherwise the first open
  cardinal adjacent cell is used. The resolver reads the selected NPC slot's
  live RAM position without forcing a full object-list rebuild, skips occupied
  adjacent cells, and logs `TELEPORT_SELECTED` with the target and landing.
  Follow-up logs showed the Weapons Merchant counter landed correctly at
  `(5,6)` but TALK still missed because the hero was not facing north, so
  selected NPC teleports now queue one raw post-teleport facing tap after the
  normal input-suppression window, neutralize input afterward, and log
  `TELEPORT_FACE`. A later retest showed `Shift+Enter` could leak through as
  Start if the hotkey was still physically held after the fixed suppression
  window, leaving the game in a menu/control-stuck-feeling state until Enter
  was pressed again. Teleport suppression now watches the non-modifier trigger
  key (`Enter` or an arrow), keeps Start/D-pad neutral until release, and only
  then runs the facing tap. A second live repro of the "hung" state showed
  input was actually neutral and the menu was closed; the selected Woman 3
  teleport had landed at `(5,7)`, where the first read treated UP/DOWN/RIGHT as
  blocked while LEFT was the NPC. The DOWN edge was later manually disproved
  and removed from the model; Brecconary still records the confirmed UP and
  RIGHT seams, and selected NPC teleport skips adjacent landings that have no
  non-target escape.
  Post-restore live testing also fixed the auto-visited marker for counter
  services when another object is selected: TALK from the weapon-shop stand
  `(5,6)` with `Exit to World Map` selected now marks `Weapons Merchant`
  visited instead of logging a no-adjacent-NPC skip.
  Next manual check: select a Brecconary NPC and press `Shift+Enter`; the hero
  should land next to or at the interaction stand for that NPC, face the target,
  and then TALK should reach the NPC/counter. Woman 3 at `(4,7)` should land at
  `(4,8)`, facing north, not at the trapped `(5,7)` stand.
- Brecconary west-wing throat follow-up: manual movement proved the pocket near
  `(3,7)` was artificially pathability-empty because live-passable type-0
  cells were missing passthrough entries. `(3,7)`, `(2,9)`, and `(3,9)` are now
  modeled as passthrough cells. Repeated `(3,7)->UP` attempts into `(3,6)`
  blocked 5/5 with no NPC or runtime block, so `(3,6)` remains closed. After
  reload, live inspect reports the throat cells as `reason=passthrough`, and
  the reachable-object filter from `(3,7)` now exposes 16 reachable objects
  instead of leaving the pocket empty.
- Brecconary east-wing throat follow-up: manual movement proved `(22,24)` is
  another live-passable type-0 false wall. `(22,24)->UP` into `(22,23)` and
  `(22,23)->DOWN` back into `(22,24)` both moved repeatedly. Before the patch,
  live inspect reported `(22,24)` as `reason=tile_type` with no permanent,
  runtime, NPC, or directional block, so this snuck in through the base town
  tile decoder rather than a learned runtime blocker. `map_reader.lua` now
  models `(22,24)` as a passthrough; after reload, the reachable-object filter
  from `(22,24)` reports 18 reachable objects.
- Brecconary weapon-shop throat bad-blocker bucket: manual movement proved the
  `(5,7)<->(5,8)` and `(5,7)<->(5,6)` edges are open both ways. These were not
  ROM tile false walls; they were stale directional blocks promoted from noisy
  selected-NPC/verifier timing evidence. Before the fixes,
  `inspect_move:5,7,DOWN` and later `inspect_move:5,7,UP` showed the model
  alone was blocking the move while tile, permanent, NPC, and runtime blockers
  were clear. `map_reader.lua` now removes both vertical directional blocks
  while keeping the still-modeled east seam into `(6,7)`.
- Combat spell-list narration first pass: after exiting Erdrick's Cave, a world
  map fight with a Red Slime exposed that battle spell menus were not being
  read. Live capture showed the SPELL submenu with cursor `D8=0 D9=0` and upper
  text containing `HEAL` / `HURT`, but the old battle parser treated cursor
  `(0,0)` as top-level `FIGHT`. `battle.lua` now recognizes visible known spell
  names on the battle spell-list screen, and `main.lua` keeps a battle spell
  submenu mode that announces the selected spell with MP cost. Live reload proof
  logged `BATTLE_SPELL: Spells. Heal. 4 MP` on the parked first spell. Next
  combat checks: move within the spell list, back out to the top-level battle
  menu, and cast a spell to verify result narration.
- Combat spell-list lag follow-up: the first spell-reader patch was too eager
  and decoded the upper battle window every battle-menu poll, which lagged out
  combat. The spell-screen detector is now only a one-time recovery probe for
  reload/attach into an unknown battle menu state; normal SPELL entry is tracked
  from the A press and should not continuously rescan upper PPU rows.
- Combat spell-list polish follow-up: live grinding confirmed most lag was gone
  but some glitching remained at battle start, SPELL menu entry, and Heal/Hurt
  cursor movement. The current disk patch removes the routine battle-start
  recovery scan, detects an A-held top-level SPELL -> `(0,0)` transition without
  an upper-window scan, and makes spell-list speech interrupt stale queued spell
  names. This patch is statically validated, but the last BizHawk auto-reload
  stopped polling after writing only a fresh log header, so it still needs a
  manual reload/restart before live judgment.
- Combat spell-list polish follow-up 2: the user's next live test confirmed
  combat-start lag is gone, with remaining glitching isolated to SPELL menu
  entry and Heal/Hurt cursor movement. `main.lua` now avoids the generic
  field-menu `COMMAND` PPU scanner in battle entirely; battle menu and spell
  list tracking read the already-cached D8/D9 cursor RAM instead, while keeping
  the expensive upper-window spell-list detector only for reload-directly-into-
  battle recovery. The script reloaded cleanly afterward; next fight should
  judge SPELL entry/cursor feel.
- Battle debuff tracking follow-up: grave combat exposed that hostile spell
  effects were still opaque. `battle.lua` now decodes the hero's `0x00DF`
  combat-status bits for Sleep and Stopspell, and `main.lua` announces only
  transitions (`Asleep` / `Awake`, `Spells blocked` / `Spells restored`) during
  battle. The battle SPELL list also gives a one-time `Spells blocked` reminder
  on entry while Stopspell is active, but does not repeat it on every cursor
  move.
- B2 Wolf follow-up (`2026-05-30`): a strong Wolf fight left Bill with MP but
  unable to cast from the field; the game repeatedly printed
  `Bill cannot yet use the spell`. Local logs showed no enemy spell narration,
  and the pre-heal town capture clarified the RAM state: Garinham `(19,1)`,
  `HP 5`, `MP 48`, `spells CE=0x00`, `CF=0x10`, `combat=0x08`, with lower text
  still `Bill cannot yet use the spell.` Since `combat=0x08` does not include
  the `0x10` Stopspell bit, the accessibility fix now handles both explicit
  Stopspell and suppressed/corrupted spell-list evidence. If the hero has no
  visible spells but level/MP says spells should exist, unavailable SPELL
  attempts say `Spells blocked.` instead of misleadingly saying
  `Spells. Empty.` `debug_tools.log_state` now also logs raw spell/status bytes
  (`CE`, `CF`, combat flags, quest flags`) for future confirmation.
- B2 Wolf stat-corruption follow-up (`2026-05-30`): resting at the Garinham inn
  did not clear the condition; instead it normalized current HP/MP to already
  corrupted max-stat bytes. After script reload, `log_state` at Brecconary
  `(24,13)` showed level 12 with `HP 15/15`, `MP 0/0`,
  `STR=0x04`, `AGI=0x03`, `ATK=0x18`, `DEF=0x1F`, `spells CE=0x00`, and
  `stat_ram BA-CF=73 10 0B 0C B5 03 01 45 C3 00 00 0F 00 0C 04 03 0F 00 18 1F 00 10`.
  EXP/gold/equipment/key/item bytes stayed coherent, while the contiguous
  player-stat range `0x00C5..0x00CE` is bad. Do not save this state at the
  king. FCEUX quick-state slot 0 and `-bak.fc0` decode as clean level-12 B2
  states at map `0x19` `(11,2)` with `HP 63/63`, `MP 52/52`,
  `STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`, and `spells CE=0x3F`.
  A log-only integrity sentinel now watches for this pattern from `log_state`,
  battle start snapshots, map changes, and battle-to-field transitions. It
  deliberately allows level-1 no-spell combat states so normal early-game
  temporary spell blocking does not become false corruption evidence.
- Warlock timing follow-up (`2026-05-30`): a later Garin's Grave B2 warlock
  fight reproduced the corruption while combat was still live. On the exact
  frame `EVENT: battle started` fired, the battle-start snapshot already showed
  `HP 56/15`, `MP 42/0`, `STR=0x04`, `AGI=0x03`, `ATK=0x18`, `DEF=0x1F`,
  `spells CE=0x00`, and
  `stat_ram BA-CF=C9 10 F1 0C B5 03 02 45 C3 00 00 38 2A 0C 04 03 0F 00 18 1F 00 10`.
  The sentinel logged `PLAYER_STAT_INTEGRITY_WARNING` before the stable
  `A Warlock draws near!` line and before the player entered the SPELL command.
  That rules out the spell menu as the trigger and points to battle
  initialization or an earlier pre-dialogue combat-state mutation.
  A heavier `PLAYER_STAT_TRACE` battle-start dump is now wired in too: when
  battle start is already suspicious, the log emits the recent `BA-CF` ring
  buffer plus a current sample and `changed=` address list so we can pin down
  which bytes flipped between the last good field frame and battle init.
- Wolf timing follow-up (`2026-05-30`): another strong B2 Wolf reproduced the
  same broader stat collapse, including combat stats. The battle-start trace
  at frame `51905` already had every retained field sample from `51894..51905`
  corrupt: `HP 52/15`, `MP 30/0`, `STR=0x04`, `AGI=0x03`, `ATK=0x18`,
  `DEF=0x1F`, `spells CE=0x00`, and
  `stat_ram BA-CF=2F 11 F9 0D B5 03 02 45 C3 00 00 34 1E 0C 04 03 0F 00 18 1F 00 10`.
  `A Wolf draws near!` did not log until frame `51965`, and the ambush attack
  text did not log until frame `52032`, so the first strike is probably not
  the trigger. After save-state restore, `log_state` on B2 `(1,11)` returned
  clean level-12 stats (`HP 52/63`, `MP 30/52`, `ATK=0x44`, `DEF=0x30`,
  `spells CE=0x3F`). The disk patch now adds per-frame
  `PLAYER_STAT_INTEGRITY_TRANSITION` detection plus
  `context=stat_transition` trace dumps; FCEUX needs a manual Lua reload before
  that newest detector is live.
- Combat opening dialogue follow-up: live logs showed battle-state detection
  and menu speech were now prompt, but `A Red Slime draws near!` did not log
  until roughly 216-246 frames after battle start. Because menu/spell speech
  can queue ahead of that late stable-dialogue announcement, the latest patch
  resets lower-dialogue baselines on battle start, interrupts immediately with
  `Battle!`, and lets the first coherent `draws near` line interrupt queued
  menu speech as soon as it is complete. Next fight should confirm opening
  announcements are not delayed or skipped.
- Combat action-dialogue speed follow-up: after the opening fix, the user
  confirmed battle starts announce properly but action/damage lines were still
  arriving late in the round. Battle dialogue now has a narrowly-scoped fast
  path for complete action/damage sentence prefixes (`attacks`, HP
  reduced/decreased, misses/dodges) after a short 6-frame confirmation. This
  path originally used interrupting speech to avoid stale menu chatter, but the
  latest audio tuning queues fast action speech instead so close combat lines
  do not cut one another off. Victory and reward pages intentionally stay on
  the normal stable reader, and leaked gold macro artifacts such as `GOLD Gold
  increases` are normalized. Next fight should judge whether attacks and damage
  land soon enough without making combat speech too chattery.
- Combat action-line miss follow-up: fresh logs showed a quick Slime fight at
  frame 7800 going from `A Slime draws near!` directly to reward text, while
  longer Red Slime rounds spoke attacks and damage. This pointed at one-hit
  kills where the text window briefly contained a complete `Bill attacks!`
  prefix followed by an incomplete `reduced by` fragment and then reward text.
  The normalizer now preserves complete action prefixes before dropping
  truncated damage fragments, and the fast path extracts the eligible action
  prefix before reward text begins. Next one-shot Slime should still speak at
  least `Bill attacks!`.
- Combat action-line repeat follow-up: the user heard `Bill attacks` repeat in
  one later fight. Logs showed one Red Slime damage line announced three times
  as the PPU rendered equivalent dot-artifact variants: `Hit . Points`,
  `been . reduced`, and trailing `5. .`. `battle.normalize_dialogue()` now
  removes isolated dot tiles between words and duplicate punctuation-dot
  artifacts before overlap/fast-path comparison. Stronger-enemy testing should
  verify that each round's action/damage line speaks once without losing the
  next round.
- Combat sliding-window redraw deduplication: the captured Wyvern sequence from
  World Map `(20,88)` is now an automated regression. Battle-only
  normalization removes attached `Hit. Points` and `been. reduced` artifacts,
  while a three-token/eight-character word matcher suppresses contained
  redraws and returns only genuine appended counterattack or reward text.
  All 43 battle tests and Lua syntax checks pass. In a post-reload Wraith
  battle at the same `(20,88)` reproduction coordinate, the opening, two hero
  attacks, enemy attack, hero damage, and combined victory/reward line each
  logged and reached the speech bridge exactly once.
- Erdrick's Cave B2 first chest-route pass: the new B2 map `0x1D` had no
  permanent directional seam model, so auto-walk toward the chest at `(9,3)`
  kept learning hidden one-way maze walls during play and eventually gave up.
  Direct `probe_edge_verify` checks promoted only 5/5 blocked approaches:
  `(5,3).south`, `(6,4).west`, `(6,5).east/south`, `(7,4).south`,
  `(8,5).west/south`, `(9,5).south`, `(5,8).south/east`, and `(7,8).west`.
  A second pass from the stairs/chest route added `(1,6).south` and
  `(2,6).south`; route-observed `(4,7).west` and `(2,6).east` were directly
  mixed, so they intentionally stay out of permanent data. A final focused
  verifier pass added `(3,5).south`, `(4,4).east`, `(4,5).east`,
  `(4,6).east/west`, `(5,7).north/east`, `(5,8).west`, `(7,8).east`, and
  `(8,7).south`. A morning follow-up after a normal stairs-to-chest route
  promoted `(6,5).west`, `(7,9).east`, `(7,7).north`, `(8,7).north`,
  `(4,7).south`, and `(4,7).west` after fresh 5/5 verifiers. After enabling
  BizHawk auto-reload and reloading for real, validation exposed `(8,7).east`
  as blocked 5/5 and `(2,6).east` as blocked 10/10; both are now modeled. With
  runtime blocks cleared, `debug_pathfind_adjacent:9,3` from B2 stairs now
  reports no path to any chest-adjacent tile. Additional bridge spot checks
  reconfirmed `(5,3).south`, `(6,4).west`, `(9,5).south`, and `(7,4).south`
  blocked 10/10. A reverse pass from chest-side `(8,3)` toward stairs added
  `(9,5).north`, `(7,4).north`, `(6,4).north`, `(5,3).east`, `(5,2).east`, and
  `(5,1).east` after clean 10/10 direct verifiers. A later chest-to-stairs
  route naturally failed at `(8,4)->DOWN` and `(8,4)->LEFT`; fresh direct
  repeats promoted `(8,5).north` and `(7,4).east` after both verified blocked
  15/15. Walkthrough context confirmed B2 should be a normal loop to the tablet
  rather than a special-gated puzzle. A later route-shaped raw pass and fresh
  `probe_edge_verify:8,9,LEFT,15` restored `(7,9).east` after 15/15 blocked
  evidence; the earlier raw crossing evidence was timing-confounded. A
  walkthrough-guided left-edge pass found the missing route shape: the intended
  loop uses B2 edge passthrough cells `(0,4)` through `(0,7)`, then returns into
  the interior. `(0,8)`, `(0,9)`, and `(0,3)` were blocked or mixed and remain
  unmodeled. That pass also promoted `(1,3).south`, `(2,3).south`, and
  `(4,3).west` after clean 5/5 verifiers. A follow-up stairs-to-chest reroute
  got deeper, then exposed an upper-left choke. Newly modeled route blockers
  are `(1,5).west`, `(4,4).west`, `(4,3).north`, `(5,2).west`,
  `(4,1).south`, `(3,1).south`, `(3,5).north/west`, `(2,3).east`,
  `(2,1).south`, and `(1,1).south`; `(1,1).south` also verified blocked 15/15
  directly. The graph then needed one more narrow edge opening:
  `(1,2)->LEFT` moved into `(0,2)` 15/15, and forced-origin `(0,2)->UP` moved
  into `(0,1)`. The next autowalk reached `(0,1)` and failed into `(1,1)`;
  `(0,1)->RIGHT` verified blocked 15/15. Follow-up graph checks and live probes
  proved the top-edge continuation: `(0,1)->UP` into `(0,0)` passed 15/15,
  probes moved right through `(1,0)`..`(6,0)`, row-1 downward entries from
  x=1..5 blocked, and `(6,0)->DOWN` moved into `(6,1)`. Static tests pass, the
  running script reports `(0,0)` and `(6,0)` as `reason=passthrough`, and
  `debug_pathfind_adjacent:9,3` from stairs `(8,9)` chooses chest-adjacent
  `(8,3)` with a 42-step route and `Face east`. Live auto-walk is now
  two-way playable: stairs-to-chest reached the chest after one reroute bounce
  near `(7,2)`, and chest-to-stairs bounced through several return-trip dead
  branches before reaching B2 stairs `(8,9)`. Runtime blocks cleared afterward,
  leaving `RUNTIME_BLOCKS map=0x1D none`. The B2 maze is done enough for now:
  avoid spending more time perfecting optional return-trip bounces unless
  normal gameplay exposes a fresh blocker. Next preferred playtesting focus is
  away from pathfinding, likely combat dialogue tuning while exiting the
  dungeon.
- Brecconary autowalk stress survey: from the town entrance, `(0,15)` proved to
  be the isolated transition tile and `(1,15)` correctly hit the
  `low_exit_count` survey-start guardrail, so the parked-NPC survey ran from
  open tile `(15,15)`. It completed with `targets=21`, `successes=7`,
  `gated_or_isolated=8`, `state_issues=6`, and zero suspected engine blockers.
  Follow-up state showed `RUNTIME_BLOCKS map=0x08 none` and no strong survey
  candidates. The state issues were false interruptions caused by normal
  post-arrival `AUTO_WALK_FACE` / NPC-hold behavior between survey targets;
  `survey_safe` autowalk now suppresses those actions while normal player
  autowalk keeps them.
- Fresh Brecconary rerun after that fix improved to `12` successes and `0`
  state issues. The remaining two suspect blockers were checked directly:
  `(5,2)->DOWN` into `(5,3)` is a real engine block and is now modeled as
  `(5,3).north`; `(19,14)->RIGHT` into `(20,14)` is passable 5/5 and is now
  covered by a survey-classifier guard for orphaned routes that actually landed
  on the suspected tile.
- Next Brecconary survey exposed route drift rather than new blockers. Two
  queued routes overshot by one tile after timeout retry/settle handling, and
  the old survey queue appended those retries after later targets. That made
  several later targets fail from a stranded `(7,10)` start. The retry ordering
  is now fixed so drift retries run immediately, and queued auto-step no longer
  holds early subpixel twitches after a timeout retry.
- Autostep timing follow-up: queued routes now keep holding through early
  movement-subpixel twitches, but timing-suspect turn re-press twitches report
  early to the route manager as direct retry opportunities instead of waiting
  for a full wall timeout. Survey ignores those timing-suspect route blocks as
  map candidates. Live Brecconary proof from `(15,15)` to the world-map exit:
  the route reached `(1,15)` with `movement_succeeded=true`,
  `blocked_events=0`, `suspected_engine_blocked=0`, and
  `RUNTIME_BLOCKS map=0x08 none`.
- BizHawk 2.11.1 side-install check: user transferred save data and reloaded
  in Brecconary under `/mnt/d/emulation/bizhawk-2.11.1/EmuHawk.exe`. Current
  live state reported `POSITION: map=0x08(Brecconary) x=0 y=15`; speech bridge
  was ready with `error=none`; `dw_script_error.log` had no entries newer than
  the earlier `MER` refactor crash.
- Short scan profile on 2.11.1 while idle in Brecconary showed no large
  frame-loop spikes. Biggest steady costs were PPU text/menu scanners:
  `check_yesno_prompt avg_ms=3.566 max_ms=10`, `check_merchant_screen
  avg_ms=1.823 max_ms=6`, and `check_command_menu avg_ms=1.499 max_ms=5`.
  `state.check_for_changes avg_ms=0.009 max_ms=1`, confirming the old `$6003`
  cartridge-work-RAM lag is not present in this run.
- Aggregate PPU stats are still high (`reads=65493755`, `cache_hits=45887003`,
  `cache_misses=19606752`), so the next emulator-API experiment should focus
  on whether BizHawk 2.11.1's bulk/string byte-reading support can reduce
  contiguous menu/dialogue/nametable scans rather than expecting individual
  `readbyte` calls to become free.
- Bulk-read experiment live result: after enabling BizHawk's automatic script
  reload and reloading the patched script, `PPU_STATS` reported nonzero
  `bulk_reads` and `bulk_bytes`. A 2,280-frame Brecconary sample used
  `bulk_reads=46482`, `bulk_bytes=1290432`. Compared with the prior 2.11.1
  idle sample, average scanner costs improved substantially:
  `check_yesno_prompt 3.566ms -> 1.246ms`, `check_merchant_screen 1.823ms ->
  0.302ms`, `check_dialogue 1.119ms -> 0.337ms`, and `check_upper_dialogue
  0.790ms -> 0.254ms`. `check_command_menu` improved more modestly from
  `1.499ms -> 1.126ms`.
- Follow-up route-lag sample in Brecconary: from `(1,15)`, forced
  `pathability_filter:refresh` over 21 objects took `59ms` and logged
  `CMD_TIMING command=pathability_filter:refresh ms=59.000`. Scan profiling
  attributed the spike to `debug_tools.tick max_ms=60`, while
  `objects.check_refresh` stayed `0ms`; this points at reachability/pathability
  computation, not PPU scanning or object refresh.
- Same sample selected `Guard 2` at `(4,8)`. Plain `pathfind` planned a 9-step
  route to `(4,9)` without crossing the 25ms `ROUTE_PLAN_TIMING` threshold.
  `auto_walk` then completed all 9 steps from `(1,15)` to `(4,9)` with each
  movement finishing in 23-28 frames, no timeout/retry reroute, and normal
  post-arrival facing/hold. Current player position after the test is `(4,9)`.
- Object pathability refresh follow-up: the refresh now uses one map-wide
  reachable-cell pass rather than one A* search per object. After a live reload
  probe, `pathability_filter:refresh` from Brecconary `(4,9)` over 21 objects
  returned normally and produced no `OBJECT_PATHABILITY_TIMING` or `CMD_TIMING`
  warning, so the command stayed below the existing 25ms timing threshold. The
  earlier 59ms sample was from `(1,15)`, so keep watching this during normal
  browsing, but the direct per-object pathfinding cost has been removed.
- Reroute-lag follow-up: the spike during Merchant 2-to-exit travel was a real
  auto-step timeout on the unmodeled Brecconary edge `(5,13)->LEFT` into
  `(4,13)`, not a scan-loop or crash issue. The map now blocks `(4,13)` from
  the east approach. After reload, a path-only probe from `(5,6)` to the
  world-map exit chose the detour through `(5,9)->(4,9)` and avoided the old
  timeout edge. Player position was restored to Brecconary `(1,15)`.
- Inn route/name follow-up: `Merchant 2` is now named `Weapons Merchant` and
  `Merchant 3` is now named `Inn` in the Services object list. The inn service
  routes to the public stand tile `(8,21)` facing east; live TALK from there
  opened `Welcome to the traveler's Inn... Room and board is 6 GOLD per night.`
  A first retest exposed a timeout on `(7,17)->RIGHT` into `(8,17)`, so that
  west approach is now modeled as blocked. After reload, auto-walk from
  Brecconary `(1,15)` queued 17 steps for `Inn`, reached `(8,21)`, and faced
  east with no new blocked edge. Player position was restored to `(1,15)`.
- Weapons merchant item-list follow-up: after the clean route to the Brecconary
  weapon counter, TALK/YES reached `What dost thou wish to buy?` but the item
  list was silent. This was not a speech backend failure; `report_merchant_state`
  was reading the wrong screen rows. `merchant.lua`/`main.lua` now try the old
  fixed shop reader first, then live scrolled contexts including the alternate
  nametable base. Live proof recovered all six offers and spoke the selected
  item; a down/up cursor pulse spoke `Copper Sword. 180 gold.` then
  `Club. 60 gold.`
- Spell menu follow-up: after the player reached level 3 and learned Heal, the
  SPELL list opened but did not speak its contents. Live state showed the
  command menu header was still detected, speech was ready, and no dialogue or
  upper-window text was available; the missing piece was a SPELL submenu reader.
  `main.lua` now tracks `submenu=SPELL` and `items.lua` maps D9 to known
  spells. The visible field list only shows `>HEAL` and does not show a
  per-spell MP cost, so accessibility speech adds NES spell costs from metadata.
  Live reload/re-entry proof under BizHawk now speaks exactly
  `Spells. Heal. 4 MP`, then `report_menu_state` shows `submenu=SPELL` with
  speech ready and no backend error.
- Erdrick's Cave B1 first-floor cleanup: after entering the cave, object
  browsing initially showed Brecconary-style NPC ghosts. `objects.lua` now
  limits live NPC parsing to town/castle terrain contexts, so dungeon/cave
  maps keep only their static objects. Live reload proof on `map=0x1C` showed
  exactly `Exit to World Map` at `(0,0)` and the old hard-coded
  `Stairs Down to B2` at `(1,1)`; the NPC filter reported no objects. Probes
  also confirmed the entrance path `(0,0)->(1,0)->(1,1)` and reverse, so
  `map_reader.lua` models `(0,0)` and `(1,0)` as Erdrick B1 passthrough cells.
  After reload, `pathfind_to:1,1` from the entrance returned
  `Path: 1 east, 1 south`, and
  `report_survey_start` was viable with `targets=2` and `reachable_area=83`.
- Survey battle safety: autonomous surveys now pause on `battle_started`
  instead of recording the interrupted target as a map failure. The active route
  is cancelled, route context is cleared, and the same target is retried when
  field movement is safe again. This should make dungeon surveys tolerable once
  random encounters start appearing; low HP still aborts the survey before
  resuming movement.
- Erdrick's Cave B1 targeted survey pass: starting from the entrance `(0,0)`
  correctly tripped the survey `low_exit_count` guardrail, so the first-floor
  survey seed is `(2,2)`. From that seed, `Exit to World Map` surveyed
  successfully. The earlier `Stairs Down to B2` survey only proved reachability
  to the old modeled coordinate; using STAIRS at `(1,1)` produced
  `'There are no stairs here.`
- Erdrick's Cave stair-coordinate correction: the ROM stair-down table has
  `1C 09 09`, and live STAIRS from B1 `(9,9)` moves to B2 `(8,9)`. Live STAIRS
  from B2 `(8,9)` returns to B1 `(9,9)`. `objects.lua` now uses those paired
  coordinates instead of the old `(1,1)` guesses. After reload,
  `current_object` at B1 `(9,9)` reports `Stairs Down to B2: here`.
- Route execution briefly produced noisy blocked-move observations at `(2,1)`
  and `(1,2)`, but direct edge probes from `(2,2)` moved north and west
  successfully; treat those as route timing noise, not map data.
- Erdrick's Cave B1 route-block follow-up: a live route from the corrected B1
  stairs `(9,9)` back to the entrance completed at `(0,0)` and had no battle
  events in the log. It did expose real hidden maze seams around `(3,4)`.
  Direct probes after clearing runtime blocks confirmed `(3,4)->UP`,
  `(4,4)->UP`, `(3,4)->LEFT`, and `(3,4)->DOWN` block in-engine despite
  walkable decoded tiles. `map_reader.lua` now models those as directional
  blocks only; after reload, `pathfind_to:0,0` from `(9,9)` chose a route
  around that central cluster.
- Erdrick's Cave B1 entrance-to-stairs follow-up: another live pass exposed
  additional real directional seams at `(2,4)` from the west, `(1,5)` from the
  north, `(7,2)` from the west, `(6,3)` from the north, `(5,7)` from the
  north, `(6,6)` from the west, `(8,8)` from the north/west, and `(8,9)` from
  the west. After reload, auto-walk from entrance `(0,0)` to
  `Stairs Down to B2` reached `(9,9)` and ended with no runtime blocks.
  One-off route observations at `(6,4)` from the west were not promoted because
  direct probes moved successfully. No battle or encounter markers appeared in
  the latest B1 log.
- Erdrick's Cave B1 probe-hardening follow-up: a later route got worse after
  four newest one-probe additions and produced many reroutes plus contaminated
  runtime blocks. Rolled back `(4,3)` from the east, `(4,1)` from the south,
  `(6,3)` from the west, and `(6,6)` from the north until repeated
  `probe_edge_verify` consensus reconfirms them. Route-only blocked
  observations now stay as soft seam evidence instead of hard runtime map
  blockers.

## Current Goal

Run the early game as a player would, using the accessibility mod as the primary interface. Capture friction, missing narration, confusing commands, pathfinding recovery problems, and quality-of-life improvements.

## Focus Areas

Location awareness:
- Announce current map, coordinates when useful, facing, exits, nearby objects, and hazards
- Make it easy to recover orientation after movement or teleport/debug commands

Object interaction:
- Verify NPC, chest, door, stair, shop, and inn workflows
- Ensure object navigation explains whether a target is reachable
- Prefer actionable failure reasons over generic no-path messages

Menus and combat:
- Confirm menu cursor narration is reliable
- Confirm combat narration exposes HP, enemy state, results, and turn outcomes clearly
- Identify missing item/spell/shop narration needed for normal play

Movement and routing:
- Prefer routes that feel stable during actual play, not only during survey loops
- Log route failures with enough context to reproduce
- Avoid permanent map-data changes without direct blocker evidence

QoL feature check:
- `auto_walk` should now speak progress on longer routes and speak completion.
- After auto-walking to an NPC, the target should be held briefly so the player
  has time to use TALK. The route should also face the target after arrival so
  TALK does not fail with "There is no one there." For moving NPCs, the hold
  should pin the selected NPC slot to the planned object coordinates rather
  than a stale live position.
- Object filters are All, NPCs, Services, Treasure, Travel, and Doors; `Q`
  cycles forward, `Shift+J` and `Shift+L` move filter categories without
  scrolling objects, and `Shift+K` jumps back to All.
- Location readout is `Shift+W` now. Do not use the old `Shift+P` habit in
  BizHawk; this machine's BizHawk global hotkeys bind `P` to Quick Load.
- `Shift+O` cycles the separate pathability filter: All, Reachable, and
  Unreachable. This stacks with the object category filter, ignores moving NPC
  occupancy, and is intended for sanity-checking larger maps without making
  rapid J/K/L browsing run pathfinding every tap.
- Overworld route guidance exists for the first dungeon, Garinham, and the
  early safety returns. Select the `Erdrick's Cave`, `Garinham`, `Brecconary`,
  or `Tantegel Castle` Travel object and press `R`, or use `route_guidance`,
  `start_overworld_route:cave`, `start_overworld_route:garinham`,
  `start_overworld_route:brecconary`, or `start_overworld_route:castle` from
  the command file. Press `R` again, run
  `route_status`, or browse the Travel filter to hear the next route waypoint.
  If a route is active and another guided Travel destination is selected,
  pressing `R` replaces the old route with a route to the new destination. If
  the player has drifted far off the expected waypoint, pressing `R` on the
  active route waypoint recalculates the next marker from the current position;
  `route_recalculate` / `recalculate_overworld_route` do the same from the
  command file. `stop_overworld_route` cancels the active route.
  First-phase overworld auto-walk is available while a route is active: press
  the normal auto-walk command or send `auto_walk` to queue one straight segment
  to the next waypoint. It stops at that waypoint, on a movement blocker, or
  when battle/menu/dialogue state interrupts field movement; it does not yet do
  full world-map A* or automatic rerouting around terrain.
  FCEUX live smoke proved the command path can begin a queued route segment:
  from `(28,13)`, `auto_walk` toward Erdrick's Cave started `source=queued_route`
  and then stopped on a blocker entering `(28,12)` from the south. Treat that
  cave approach as a route-data follow-up, not an auto-walk executor failure.
  After starting the route, `current_object` should report a `Route next`
  waypoint rather than the plain landmark. `O` remains the plain heading/path
  preview for the selected object, and `U` drives the one-segment auto-walk
  behavior.
- The Erdrick's Cave route includes a one-time bridge warning about stronger
  monsters beyond the crossing. During live testing, check whether this is
  helpful and quiet enough. The route now uses additional mountain-pinch
  markers after live evidence showed the old long heading from `(30,32)` led
  into blocked terrain: `East choke approach`, `Eastern mountain lane`,
  `North ridge bend`, then `North trail marker`. `East choke approach` at
  `(35,32)` and `Eastern mountain lane` at `(35,24)` are exact markers now;
  this prevents the route from advancing one tile early and telling the player
  to turn before the choke lane has really been cleared.
- The Erdrick's Cave route also uses the lower bridge detour after live
  evidence showed the direct first-bridge-to-pinch leg could block: from
  `Brecconary road`, it now routes to `Bridge south bend`, `Bridge lower west
  lane`, `Bridge west bend`, `Upper bridge lane`, and `East choke approach`.
  The immediate repro was a blocked north move from `(45,34)` into `(45,33)`,
  followed by blocked north attempts from `(41,35)`, `(40,35)`, and `(39,35)`
  when the detour was still too diagonal. A later log showed the old
  `Mountain pinch turn` marker caused a short west-then-east reversal, so it
  is no longer a mandatory step on this bridge/east-choke segment.
- The Brecconary and Tantegel Castle safety routes reverse the cave route's
  mountain-lane and bridge markers, using `East choke approach`, `Upper bridge
  lane`, `Bridge west bend`, `Bridge lower west lane`, and `Bridge south bend`
  before heading directly to safety. Live return evidence showed blocked
  direct moves into `(39,34)`, `(41,34)`, and `(42,34)`, while the lower bend
  through `(44,38)` reached town cleanly. The old safety marker at `(45,34)`
  was removed because it sent the player north, then immediately back south
  toward town. These routes warn once that monsters
  should become safer beyond the bridge. From Garinham, these safety routes
  now first guide through the north-coast and shoulder markers back toward
  `Garinham east field` and `Erdrick's Cave road` before using the already
  tested cave-to-safety route. The Garinham-bound route uses those same
  markers in reverse after `Erdrick's Cave road`; it currently includes
  `Garinham east field`, `Garinham ridge entry`, `Garinham east ridge`,
  `Garinham shoulder bend`, `Garinham shoulder east step`, `Garinham mountain
  shoulder`, `Garinham north coast lane`, `Garinham north coast west lane`,
  `Garinham outskirts`, and `Garinham approach` `(2,2)` before the town at
  `(1,2)`. It completes on map `0x09`. The
  safety routes still complete on the destination maps (`0x08` for
  Brecconary; `0x04` / `0x05` for Tantegel Castle).
- Read-only hotkey speech now queues instead of interrupting current speech:
  position, HP/MP, level, gold, experience, stats, screen text, and `R` route
  guidance/status use non-interrupting speech. While a manual step is still
  settling, `R` may report an active route's status, but starting a new route
  or using movement-changing object controls waits for stable movement and
  says `Wait for movement to finish`.
- Visited flags are session-only and map-scoped. Use `Shift+V` or
  `mark_visited` to mark manually; `clear_visited` clears the current map and
  `clear_visited:all` clears all maps. After TALK dialogue, the auto-visited
  marker now falls back to live NPC RAM if the cached object list has stale NPC
  coordinates, which can happen under BizHawk's disabled periodic NPC refresh.
  It also recognizes modeled service interaction stands such as Brecconary's
  weapon-shop counter even when that merchant is not the currently selected
  object. The marker stays armed for slow dialogue stabilization and survives
  BizHawk source reloads, so delayed NPC text should still mark the talked-to
  NPC without losing existing visited flags on `touch main.lua`.
- Selected-object teleport uses `Shift+Enter` for the selected object, with
  NPCs landing at an adjacent or service interaction cell, and
  `Shift+direction` for an adjacent landing on that side of the target.
- Watch selected-object teleport near doors/stairs and moving NPC clusters.
  The first manual test did not show lost keyboard input after teleport; logs
  showed the player boxed in at `(4,6)` on map `0x05` by NPCs at `(3,6)` and
  `(5,6)`, the door south, and a noisy north doorway edge.
- Direct selected-object teleport to an unwalkable target should speak a simple
  player-facing refusal, without mentioning debug-only `near` or `force` flags.
- Latest manual pass: Guard 1's route recovered and reached an adjacent tile,
  but the post-arrival facing input stepped into the guard's planned tile
  because the NPC hold used his wandered live position. `route_manager.lua` now
  holds the selected NPC at the planned target tile, and the false-visited case
  still behaves correctly.
- Stale command-menu cache was confirmed from live logs: after a TALK/dialogue
  attempt, `EVENT: command menu opened` had no matching close event, and later
  `auto_walk` commands were blocked before planning. `main.lua` now treats the
  raw `COMMAND` header match as scanner input only unless a confirmed live
  field-menu session is active. Movement and auto-walk stay blocked for that
  confirmed live session while the cursor hold or raw header is present, so a
  still-open command menu cannot let auto-step record false field blocks after
  the cursor blink/hold expires; TALK and menu-close paths clear the live flag
  before lingering PPU text can freeze field movement.
- Console reloads can leave required modules cached. A Guard 1 retest after a
  console reload still used the old `route_manager.lua` target-hold code and
  walked the hero onto Guard 1's tile at `(7,5)`. `main.lua` now clears project
  modules from `package.loaded` before requiring them. After a fresh reload,
  the visible lower text `'There is no one there.` was logged and spoken, while
  `report_upper_dialogue_state` reported `menu_raw=true menu_active=false`.
- A later Guard 1 playtest at `(18,2)` found a different TALK-failure silence:
  the normal filtered lower reader captured `'There is no one there.`, but the
  y<=3 row-1 cleaned dialogue path missed it and left `announced_lower` empty.
  The row-1 reader now falls back to the already-filtered lower dialogue when
  its fixed-row scan finds no lowercase text. An intermediate bad reload hit
  Lua 5.1's local limit, but the corrected file validates and later live
  reload probes have succeeded.
- Person 1 in the reachable NPC list can still be temporarily blocked by moving
  NPC traffic because the reachable filter intentionally ignores live NPC
  occupancy. The player-facing no-path hint should call that NPC clutter, not a
  closed door, when an NPC-free route exists. `route_manager.lua` now prioritizes
  that explanation over nearby closed-door frontiers. Live note: the reload
  verification accidentally auto-walked the post-reload selected `Exit to World
  Map`; current logged position after cleanup was map `0x04` `(11,28)` with
  runtime blocks clear.
- Reload-lag follow-up: after module-cache clearing, the old BizHawk shim's
  `FCEU` global survived reload and made `emulator_compat.lua` falsely detect
  FCEUX, disabling BizHawk scan throttling. The live symptom was a fresh log
  header with very slow frame progress and `report_scan_stats` saying
  `SCAN_PROFILE unavailable: not running under BizHawk`. `emulator_compat.lua`
  now detects real BizHawk APIs before trusting a stale `FCEU` shim; live
  `touch main.lua` recovery reached `launcher_probe:reload_detect` at frame 60
  and produced normal BizHawk scan stats.
- Reload-input follow-up: after the BizHawk/FCEUX detection fix, stale wrapped
  `joypad`/`input` tables could still be captured as native on reload. That
  could make `joypad.read()` empty and make `joypad.set()` neutralize controls,
  matching the observed `X`/`Z` failures and odd emulator-key behavior.
  `emulator_compat.lua` now unwraps previous adapter closures back to native
  BizHawk APIs and replaces its `FCEU.frameadvance` wrapper on every reload.
  Live reload check reached frame 180, reported `cache_flushes=179`, and had no
  stuck keys in `input_status`.
- Pathfinding confusion follow-up: the no-path behavior after manual movement
  around Guard 1/door terrain was caused by manual blocked steps being promoted
  into runtime blockers on map `0x05`. `route_manager.lua` now treats
  `queued_route=false` blocks as diagnostic seam observations only. A live
  post-reload snapshot reported `RUNTIME_BLOCKS map=0x05 none`.
- Guard 1 overlap follow-up: post-arrival facing was still being interpreted by
  `auto_step` as a player tap, which could walk onto the NPC square. The live
  retest after the suppression patch stayed at `(4,7)` with Guard 1 one tile
  north at `(4,6)`.
- Route-blocking follow-up: if a queued route is blocked by a live NPC, it
  should now be treated as temporary NPC movement instead of map geometry. A
  separate chest route from `(4,7)` hit a current runtime seam block at
  `(4,6)` from the south; current NPC blockers were elsewhere, so that case is
  not NPC clutter.
- Command-menu open follow-up: after the King dialogue fix, opening the command
  menu could still briefly speak the last-used cursor selection before settling
  on TALK. `main.lua` now debounces the opening announcement for six frames and
  uses the first real cursor movement or settled cursor item, so the expected
  open line is `Command. TALK` without a stale selection first. After killing
  and restarting the script, the user physically retested the fix and confirmed
  it worked as expected.
- Death-square follow-up: manual movement found a damaging/death tile on
  Tantegel Castle map `0x04` at `(10,18)`. Entering it from `(10,19)` logged
  `Lost 15 HP. HP 0`, then the normal `Thou art dead.` / Death King recovery
  sequence. Death King dialogue narration passed. The tile is now modeled as a
  hazard, not a wall, so auto-walk, teleport walkability, and tap-to-step
  extension avoid it while deliberate held manual movement remains under
  player control.
- Reachable NPC dialogue pass: the user finished dialogue testing all
  reachable NPCs in this part of Tantegel Castle. Waiting for NPC movement
  remained tedious enough that Guard 1 was reached by teleport. The castle
  merchant-labeled NPCs behaved as dialogue-only NPCs in this pass; keep an
  eye on whether they ever sell later, and consider removing them from the
  Services filter if they stay dialogue-only.
- First-town merchant follow-up: Brecconary `Merchant 1` also behaved as a
  dialogue-only NPC (`Please, save us from the minions of the Dragonlord.`),
  despite being listed under Services. When the merchant moved near the top of
  town, the y<=3 dialogue reader spoke only `Please, save us from`. The row-1
  dialogue path now prefers the richer normal lower-window candidate when the
  fixed y<=3 row scan catches only part of a multi-line message.
- Brecconary service-discovery follow-up: the user talked to all reachable
  townspeople in the first town and still did not find an inn keeper or real
  merchant service. Woman 3 said she was near the shop. The shop/inn actors may
  be blocked targets, may be represented differently than normal wandering
  NPCs, or may need a shop-counter/object interaction path rather than ordinary
  TALK-to-NPC handling.
- Brecconary weapon-shop follow-up: the true weapon/armor merchant is
  `Merchant 2` at `(5,4)`. The safe public access path reaches the doorway/
  counter square at `(5,6)`; face north and TALK even though the merchant object
  is two tiles north. The route enters through `(5,8)->(5,7)->(5,6)`; both
  `(5,7)` and `(5,6)` are false-wall passthrough tiles in the map model. Routes from the merchant pockets to the
  world-map exit proved `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`, `(6,4)`, and
  `(6,5)` are trap/service-pocket cells for autonomous movement; the map model
  keeps those pathfinder-forbidden and also blocks the false `(8,5)->LEFT`
  shortcut into `(7,5)`.
- Brecconary Merchant 2 item-list narration regression is fixed after the
  `main.lua` local-reduction refactor. The shop list is rendered in fixed
  screen/menu rows even while field scroll registers remain non-zero, so
  merchant scanning now reads screen coordinates by default. Live proof after
  reload: the list reported all six offers and a Down input spoke
  `Clothes. 20 gold.`
- Brecconary counter-service discovery: raw map block `0xF` marks the shop
  counter/large-tile trigger. `Inn` at `(10,21)` is the inn keeper; TALK from
  the public stand tile `(8,21)` while facing east opens `Welcome to the
  traveler's Inn... Room and board is 6 GOLD per night.` `Merchant 4` at
  `(25,25)` is the tool shop; TALK from `(24,25)` while facing east opens
  `Welcome. We deal in tools.` `objects.lua` now exposes these confirmed
  service interaction tiles directly, while keeping the generic adjacent raw
  large-tile inference for future service counters. Later Merchant 4 probing
  superseded the route target: `(24,25)` remains a blocked movement seam and
  `(25,26)` remains an alternate pocket; normal service routing should use the
  public `(23,25)` stand facing east.
- Weapon-shop item list follow-up: the buy/yes-no prompt worked, but the item
  list initially spoke field command labels and raw cursor coordinates because
  the shop list also shows a `COMMAND` header and reuses menu cursor RAM.
  `merchant.lua` now decodes the visible scrolled shop rows and prices, and
  `main.lua` suppresses command-menu speech whenever that merchant layout or
  lower shop dialogue is present. The merchant scan also keeps running while
  the shop prompt sets the generic dialogue hint, so the item reader does not
  starve after a buy/error/continue cycle. Live validation completed a Copper
  Sword not-enough-gold loop and returned to the list with `Bamboo Pole. 10
  gold.` instead of `STATUS` / `SEARCH`.
- Ctrl+W crash follow-up: the script crashed immediately after `Ctrl+W` with a
  fresh `dw_script_error.log` entry in `snapshot.update`; the fatal line was
  adapter logging through BizHawk `console.log()` while memory fallback was
  active. Adapter logging is now protected. A follow-up reload-window crash
  also showed temporarily unavailable BizHawk memory APIs, so the adapter now
  fails closed for unavailable reads/writes instead of crashing. The second
  live reload succeeded and speech reported ready.

## Initial Gameplay Pass Checklist

Use this as a lightweight first pass:
- Start or load a normal early-game state
- Confirm speech backend readiness with `speech_status`
- Confirm player state with `report_position` or `log_state`
- Navigate around the starting castle/interior without visual assumptions
- Interact with the king/throne-room objects if available
- Use stairs/doors/exits intentionally
- Visit the first town and interact with NPCs/shops if reachable
- In town, verify visited flags and Services/Treasure/Travel filter categories
- On the world map, select `Erdrick's Cave`, `Brecconary`, or `Tantegel
  Castle`, press `R` or run `route_guidance`, browse the small Travel route
  layer, verify `current_object` selects `Route next`, and verify
  `route_status` plus one route-progress announcement
- Enter a simple combat encounter and evaluate narration
- Record every point where the player would feel lost, under-informed, or unable to recover

## Open Gameplay Issues

### GP-002

Severity: Medium

Area: Command menu narration / map-position sensitivity

Status:
Resolved for the latest King/dialogue and command-menu opening reports. Keep
watching this area during normal play, but there is no active blocker at the
2026-05-05 wrap-up.

Description:
Manual testing found that in certain parts of the map, the command menu or
dialogue options do not read correctly. The latest scripted snapshots only saw
the status row (`menu_raw=false menu_active=false lower=""`), so the bug was
not present at capture time. `main.lua` now keeps command-menu scanning active
during current/recent player input even while BizHawk dialogue throttling is
active, but automated simulated A/B presses did not open the field menu in the
live session.

Next evidence to collect:
- Reproduce one bad command-menu read.
- Immediately capture `report_position`, `input_status`, and ideally
  `report_upper_dialogue_state` plus `report_movement_state:menu_bad_region`.
- Compare with a nearby position where the command menu reads correctly.
- Check whether the issue correlates with scroll/camera bytes, row-1 command
  menu parsing, or map-specific PPU layout.
- For King/dialogue silence specifically, the latest bad-state `Ctrl+D` dump
  contained no visible command/menu/dialogue text in raw PPU, and the live
  parser state also saw only status text with speech ready. The diagnostic
  samplers now clear BizHawk's PPU cache first; if the next dump is still blank
  while text is believed to be visible, treat it as a capture-timing or
  alternate-domain problem rather than a normal parser-row bug. The next
  `Ctrl+D` dump should include a `PPU source comparison` section to compare
  native `ppu.readbyte` with available nametable-like BizHawk memory domains.
- Follow-up resolved the source issue: native BizHawk `ppu.readbyte` was the
  blank source, while `CIRAM (nametables)` had the actual King question,
  `COMMAND`, and Yes/No/menu text. The compatibility layer now prefers that
  nametable memory domain. Live reload proof spoke the King question and
  `YES NO prompt. YES`; continue playtesting menu/dialogue normally from here.
- The remaining silent King farewell was a separate stale-base issue. The dump
  had the farewell text (`Goodbye now... Take care...`) in the nametable, but
  `PPUCTRL` reported `base_nt=0` while the text still required NT1-first screen
  order. The lower-dialogue reader now tries the alternate nametable order when
  it contains more lowercase dialogue. Retest on the next King save/continue
  flow; the final farewell should now speak.
- A follow-up confirmed the King dialogue path is working. Continue with normal
  command-menu playtesting.
- After a script restart, the command-menu opening debounce also passed the
  physical retest: the previous selection is no longer spoken before TALK.

### GP-001

Severity: High

Area: Emulator default / BizHawk performance

Status:
Historical BizHawk transition note: the swap was accepted as successful enough
to continue normal playtesting from the BizHawk path on 2026-04-30, and basic
manual testing on the first two maps after the conversion found scripts
behaving as expected. The 2026-05-18 same-save bakeoff later moved normal
gameplay launches back to FCEUX because BizHawk still had player-facing lag and
audio cut-outs around route/seam work. Keep this entry as the historical lag
context for future BizHawk tuning.

Description:
BizHawk remains the explicit automation/debug emulator path. It can launch the
ROM and accessibility script, and the script can speak through title/continue flow.
Early gameplay was initially super laggy once the game proper started, but the
current BizHawk-only throttles have substantially reduced scan load during the
king's boot dialogue.

Reproduction steps:
- Launch the explicit BizHawk path with `./launch_dw.sh --emulator bizhawk`
- Continue an existing quest
- Wait until the game proper starts

Observed behavior:
- Title flow and speech work.
- Lag improves with compatibility-layer PPU caching and gameplay scan
  throttling.
- During the king's normal boot dialogue, current profiling shows only
  dialogue/yes-no scans running; command-menu, merchant, and object refresh
  scans are suppressed.
- Lag did not fully stop after king dialogue ended in the live script that was
  running before the latest state-detector patch.
- Spoken status summaries appearing inside king dialogue were caused by stray
  BizHawk keyboard hotkeys, not by dialogue parsing. BizHawk keyboard hotkeys
  are now disabled by default.
- The object explorer initially stopped working under BizHawk because the first
  hotkey gate blocked every keyboard shortcut. The current patch restores the
  default object/navigation hotkeys through `bizhawk_keyboard_hotkey_allowlist`.
  The `N` tile/coordinate diagnostic is also allowed for playtesting, while
  broader status/raw-dump diagnostics stay blocked.
- Pressing `N` then provided a clean audio-cutout repro: the spoken coordinate
  check was coupled to the full `tile_diag.txt` dump and could stall audio for
  about 1.5-2 seconds. The current patch keeps `N` to the compact spoken
  coordinate/tile summary by default; set `tile_diag_dump_on_hotkey=true` only
  for slow forensic dumps.
- A command-file `current_object` probe still returned an object description,
  so this was a keyboard-filter issue rather than an object-list failure.
- Normal play audio is now reported smooth, but route/path commands can still
  glitch emulator audio while processing. A live sample showed command/object
  refresh spikes rather than steady frame-loop lag: `debug_tools.tick
  max_ms=1931` and `objects.check_refresh max_ms=2068`.
- Dialogue is no longer lagging, but live testing showed it could speak before
  all new text arrived. The current patch clears BizHawk's PPU cache for
  dynamic dialogue scans so partially rendered cached text should not announce
  as stable.
- Object navigator caused an approximate two-second BizHawk freeze. The current
  patch makes BizHawk object descriptions skip reachability/path checks by
  default; explicit `pathfind` and `auto_walk` still do the heavier work.
- Object-browser hotkeys now explicitly request brief descriptions only:
  name/direction/count, without path reachability previews or raw coordinate
  debug suffixes. Explicit `O` pathfind and `U` auto-walk remain the route-work
  commands.
- After reloading with the latest object-refresh patch, broad lag is mostly
  under control. Object-list navigation still causes a small amount of lag, but
  profiling no longer shows script-side object/hotkey spikes.
- Rapid J/L object navigation now coalesces speech by default with
  `object_nav_speech_coalesce_frames=18`: selection changes immediately, but
  only the latest object description speaks after a short pause. K/current
  object still speaks immediately. The first 6-frame trial still flushed
  repeatedly during manual tapping, so this wider delay needs live BizHawk
  audio confirmation.
- The BizHawk audio config trial helped: with `SoundBufferSizeMs=200`,
  `SoundThrottle=true`, `FrameSkip=0`, and `Rewind.Enabled=false`, background
  window work no longer reproduced the previous audio glitching. One glitch
  occurred while focused in the emulator, but it has not reproduced.
- Wrap-up manual testing on 2026-04-30 covered the first two maps at a basic
  level. Apart from audio stuttering, script behavior matched expectations
  after the emulator conversion.
- Random emulator audio freezes were also observed, especially while working in
  other windows. This still needs correlation with `CMD_TIMING` and scan stats;
  if no script spike appears, treat it as a BizHawk/Windows focus or scheduling
  issue rather than the Lua loop.
- Normal movement/menu responsiveness after reloading the latest script still
  needs a fresh player-control check.
- Standing by the king on map `0x05`, auto-walk to the selected stairs returned
  "No path found". After the ROM-domain fix, live probes now show sane map
  dimensions and tile data: `(8,8)` is passable stair/corridor passthrough,
  while `(4,7)` is a closed magic-key door. The remaining no-path is normal
  locked-door route state, not a BizHawk ROM decode failure.

Expected behavior:
- Emulator remains responsive enough for normal play while the accessibility
  script runs.

Evidence:
- PPU caching improved title lag but not field lag enough.
- Current hypothesis is that field gameplay runs too many PPU-heavy scans each
  frame under BizHawk's slower Lua memory-domain APIs.
- A BizHawk-only scan-throttle patch has been added for title-state rescans,
  yes/no prompt scans, command/battle menu checks, merchant analysis, lower
  dialogue, and upper dialogue.
- Latest king-dialogue sample after boot-dialogue grace: `PPU_STATS
  reads=123840 cache_hits=108736 cache_misses=15104`; active scan profiles
  were lower dialogue, yes/no prompt, and upper dialogue only.
- Latest post-dialogue/player-control sample before the state patch:
  `state.check_for_changes calls=240 reads=0 ms=26984 avg_ms=112.433`. The
  source was the BizHawk path reading `$6003` every frame for sprite CHR/battle
  detection.
- Latest route/path command patch caches static object sources per map, adds
  `CMD_TIMING` logging for slow command handlers, and throttles repeated
  `CAN_WALK false` debug lines.
- Latest object/dialogue patch clears dynamic text PPU cache reads under
  BizHawk and adds `bizhawk_object_reachability_descriptions=false` so object
  navigator speech is quick by default.
- Latest post-dialogue object-list samples:
  `objects.check_refresh max_ms=1` for command-file object navigation, and a
  real-hotkey sample showed `hotkeys.update max_ms=1` plus
  `objects.check_refresh max_ms=1`. The earlier two-second object-refresh spike
  is no longer present with `bizhawk_periodic_npc_refresh=false`.
- The object-nav speech coalescer is covered by `test_hotkeys.lua`; tests cover
  delayed J/L speech, rapid-tap latest-only speech, K/current-object immediate
  speech, route-action clearing, and `object_nav_speech_coalesce_frames=0`.
- `emulator_compat.lua` now scores BizHawk ROM candidate domains/address
  mappings so headerless PRG-only ROM domains still emulate FCEUX
  `rom.readbyte()` offsets. New validation: `test_emulator_compat.lua` covers
  full iNES and headerless PRG domain layouts.
- Live follow-up on 2026-04-29 confirmed the map `0x05` stair path now decodes
  correctly under BizHawk: `inspect_tile:8,8` returned `dims=10x10`,
  `tile=15.0`, `reason=passthrough`, and `effective_passable=true`;
  `inspect_move:4,6,DOWN` returned `reason=door_closed` for `(4,7)`.
- Route messaging now detects a closed-door frontier on no-path plans and tells
  the player to get/use a magic key instead of only saying "No path found".
  Covered by `test_route_manager.lua`.
- Live playtesting after this still showed the door as closed after the player
  opened it. Root cause: BizHawk `memory.readbyte()` was still reading
  `$600C/$600D` opened-door slots through `mainmemory`, but DW1 stores those
  slots in cartridge work RAM. `emulator_compat.lua` now routes `$6000-$7FFF`
  reads through System Bus / PRG-RAM-style domains, and
  `test_emulator_compat.lua` plus `test_map_reader.lua` cover opened-door RAM.
- Manual retest after the cartridge-RAM fix confirmed the expected flow from
  game launch: open all throne-room chests, open the `(4,7)` door, and walk
  down the stairs into the castle proper.
- The same run showed auto-walk audio pain around blocked-step retries. Local
  config now uses `auto_step_timeout=45` and `auto_step_block_retry_limit=1`
  to shorten blocked-route retry windows.
- A 2026-05-05 fresh-game playtest found manual autostep feeling like native
  BizHawk movement: direction keys worked, but the player often had to hold
  until the game turned or stepped. Recent logs showed many 45-frame
  `auto_step timeout retry` paths, and the checked-in config had quick
  turn-only re-presses disabled. `auto_step_turn_repress_limit` is now `1`
  again so a tap that only turns gets one prompt follow-up press before the
  slower timeout retry path. Follow-up logs showed early subpixel changes could
  still mark a turn-in-place as movement started, suppressing that quick
  re-press until the timeout path; `auto_step.lua` now treats very early
  subpixel-only starts as eligible for the turn re-press too.
- The same fresh-game pass exposed stale object-browser NPCs after entering
  the second map from the throne room: old map `0x05` NPCs could remain
  selected on map `0x04` until routing hit a blocking live NPC and refreshed
  the list. Fresh Lua startup transitions cleanly; the repro returned only
  after touching `main.lua` for a BizHawk reload. The stale-state PPU dump did
  not show the prior wrong-source bug, so the fix is reload/transition-state
  based. The first signature patch fixed the current map after reload but not
  the next transition. The current patch keeps accepted NPC signatures in
  `_G.DW_OBJECTS_RELOAD_STATE`, observes the latest current-map NPC coordinate
  signature during normal gameplay frames, masks off direction/frame bits, and
  hides NPCs on map entry while RAM still matches the just-observed previous
  map. Retest by touching `main.lua`, waiting for reload to settle, using
  STAIRS between map `0x05` and `0x04`, and checking the NPC filter for the
  destination map's NPCs rather than the map just left. User retest confirmed
  the desired result after reload: 4 NPCs on map `0x05`, and 20 NPCs on map
  `0x04`.
- A later 2026-04-30 first-town manual run reported that route/path commands
  still caused lag, name-entry clicks could double-enter letters, and movement
  could overshoot cells. The live `dw_debug.log` did not contain `CMD_TIMING`
  or scan-profile spikes for the hotkey-triggered `O`/`U` work, so route-plan
  timing is now logged separately as `ROUTE_PLAN_TIMING`.
- The same log showed a concrete queued auto-walk overshoot pattern: after a
  south step to `(1,4)`, the next queued `right` step completed at `(1,5)`
  while the planned seam was `(2,4)`; after a right segment to `(3,5)`, the
  next queued `down` completed at `(4,5)` while the planned seam was `(3,6)`.
  `auto_step_route_turn_settle_frames=16` now pauses queued routes before
  changing direction, while straight segments can still chain quickly.
- Chosen-path summaries remain in the log, but tile-by-tile chosen-path dumps
  are now opt-in with `pathfind_log_steps=true` because the detailed dump is
  slow and noisy during ordinary playtesting.
- Focused wrap-up validation after making `N` cheap and object browsing brief
  passed `luac -p hotkeys.lua objects.lua route_manager.lua config.lua
  test_hotkeys.lua`, `lua test_hotkeys.lua`, `lua test_route_manager.lua`,
  `lua test_objects.lua`, and `git diff --check`.
- Route-turn follow-up validation passed `luac -p auto_step.lua pathfinder.lua
  route_manager.lua config.lua test_auto_step.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, `lua test_pathfinder.lua`, and
  `git diff --check`. `test_pathfinder.lua` still prints the known WSL
  Tolk/`cmd` warning before passing.
- A follow-up live log after reloading showed the queued route turn-settle
  working for a 2-step route, but also exposed the remaining autowalk lag as
  route planning: `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_15 ...
  path_len=2 ms=1978.000`. `pathfinder.lua` now prunes adjacent candidates that
  cannot beat the current shortest landing path and defers reachable-area
  diagnostics unless needed for an equal-length tie or no-path evidence.
- The same run's quickload/town object issue matched a two-phase object refresh:
  static objects were available first, while NPCs were deferred until a later
  refresh. Under BizHawk scan throttling that delay could leave only "Exit to
  World Map" in Brecconary briefly. `objects.needs_refresh(map_id)` now lets
  map-entry and deferred NPC refreshes bypass the periodic 120-frame throttle.
- Rain Shrine re-entry exposed the related stale-signature edge case on FCEUX:
  after leaving to the world map and descending again, the map ID and terrain
  can settle in separate frames; script reloads can also restart while already
  inside Rain Shrine. In both paths, the old man's NPC RAM matched the already
  accepted Rain Shrine signature, so the stale-previous-map guard waited out
  the long retry budget before accepting him. `objects.lua` now quarantines
  byte-identical NPC RAM only when it comes from a different known previous NPC
  map. World-map re-entry, same-map terrain flips, and same-map script reloads
  now let known same-map NPCs populate on the first deferred refresh.
- Route-planning/object-refresh validation passed `luac -p pathfinder.lua
  objects.lua main.lua test_pathfinder.lua test_objects.lua`,
  `lua test_pathfinder.lua`, `lua test_objects.lua`, `lua test_route_manager.lua`,
  `lua test_map_survey.lua`, `lua test_auto_step.lua`, and `git diff --check`.
- Live retest after script reload confirmed the object list populated quickly,
  but auto-walk still choked and then cancelled for path drift. The log showed
  `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_4 ... path_len=13
  ms=1836.000`, followed by drift during turn-settle: after reaching `(4,14)`
  and preparing to turn up, the player slid to `(5,14)` and the route cancelled
  with `route_drift_off_path`.
- `auto_step.lua` now actively neutralizes the D-pad during route-settle frames,
  not just the first post-step release frames. `pathfinder.lua` now uses a
  per-plan walkability snapshot from `map_reader.lua`, with a fallback per-search
  cache, so A* does not repeatedly call the slower map-reader walkability path.
- Latest live retest showed auto-walk lag is reduced but still audible, and
  `O` show-path lags too. The log showed auto-walk route plans at `path_len=13
  ms=1852.000` and `path_len=10 ms=1238.000`; show-path route previews logged
  `path_len=7 ms=1422.000` and `path_len=1 ms=1514.000`. Because the 1-step
  preview still lagged, the likely culprit is fixed route-command overhead,
  especially forced live NPC refresh/freezing under BizHawk.
- BizHawk now skips forced live NPC refresh before `O`/`U` route plans by
  default (`bizhawk_route_refresh_npcs=false`) and skips auto-walk's NPC RAM
  freeze by default (`bizhawk_autowalk_freeze_npcs=false`). FCEUX keeps the
  previous behavior, and both BizHawk options can be turned back on for a
  blocker/NPC-specific investigation.
- The same log still showed route drift: after a first `right` step from
  `(0,15)` to `(1,15)`, settle before a planned `up` drifted to `(2,15)`; after
  a right segment from `(6,16)` to `(7,16)`, settle before a planned `up`
  drifted to `(8,16)`. `auto_step.lua` now actively releases route-owned D-pad
  input after the inject window as well as during turn-settle frames.
- Latest route-lag/drift validation passed `luac -p auto_step.lua
  route_manager.lua config.lua pathfinder.lua map_reader.lua objects.lua
  main.lua test_auto_step.lua test_route_manager.lua test_pathfinder.lua
  test_map_reader.lua test_objects.lua test_map_survey.lua`,
  `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, `lua test_map_reader.lua`,
  `lua test_objects.lua`, `lua test_map_survey.lua`, and `git diff --check`.
- 2026-04-30 follow-up from quick slot 1 in Brecconary: warming the current map
  grid during map-entry object refresh removed the first usable `O` /
  `auto_walk` route spike to Person 2; the prior cold route was about
  1.7-1.9 seconds. 2026-05-05 live castle play then showed that moving the cost
  to map entry made transitions hitch under BizHawk (`objects.check_refresh
  max_ms=1846`), so BizHawk now skips map-entry grid prewarm by default and
  builds the grid lazily on first route/path use. FCEUX keeps prewarming, and
  BizHawk can opt in with `bizhawk_map_entry_prewarm_path_grid=true`.
- The same live route reached the intended adjacent tile `(10,15)` and ended
  with neutral input. The old turn-settle drift signatures did not reappear.
  There is still a smaller executor issue: the first facing/step from the town
  entrance can consume one timeout/brute-force retry before walking succeeds.
- If audio still cuts out shortly after quickload or map entry, first inspect
  `objects.check_refresh max_ms` and whether it coincides with lazy first-route
  path-grid work before moving any cost back onto the transition frame.
- Latest user retest: manual walking overshoot is much better, with remaining
  overshoot mostly when several movement presses are entered rapidly. Auto-walk
  audio is improved, but a lag spike still happened near the end of route
  attempts. Fresh logs showed the latest route reached the intended adjacent
  tile `(15,19)` with neutral input and no runtime blockers; the suspicious
  spike is `objects.check_refresh max_ms=1658` from route cleanup. BizHawk now
  skips the immediate post-route object refresh by default with
  `bizhawk_route_cleanup_refresh_objects=false`.
- Live validation after reloading the patch completed two Brecconary auto-walks:
  Person 4 from `(0,15)` to `(1,14)`, then Person 2 from `(1,14)` to `(9,14)`.
  Both ended adjacent to the target with neutral input and no runtime blockers.
  Around the longer 10-step route, `objects.check_refresh max_ms=0`,
  `debug_tools.tick max_ms=3`, and `auto_step.update max_ms=1`.
- User hands-on retest after that patch confirmed auto-walk is behaving much
  better, reaching intended targets, and the lag seems under control.
- King dialogue follow-up: the main King greeting now reads in correct screen
  order, but the Yes/No prompts initially repeated the tail of the previous
  dialogue page before the question. The worktree now strips that overlap so
  the save prompt should speak just `Will thou tell me now...` and the continue
  prompt should speak just `Dost thou wish to continue thy quest?` before
  `YES NO prompt`.
- Latest lag check: BizHawk's config is already on the safer audio/throttle
  baseline. The latest scan stats instead point at script-side spikes,
  especially object refresh and route/movement work. For the next lag repro,
  use `reset_scan_stats`, perform one action, then `report_scan_stats` before
  changing emulator timing settings.
- Reload/menu silence follow-up: after reload near the King, speech backend
  diagnostics were healthy but the command-menu scanner saw no menu at
  `scroll_tiles=22 base_nt=1`. The worktree now scans both nametable wrap
  orders for command-menu and Yes/No UI text. Retest physically by opening the
  command menu and using TALK near the King; automated debug A input still does
  not reproduce a real menu open here.
- The first PPU dump for the remaining silence did not include an active menu
  or dialogue page and only covered lower rows. `Ctrl+D` now writes a full
  0-29-row PPU dump with decoded NT0/NT1 wrap orders and parser match hints.
  If silence remains, capture `Ctrl+D` while the menu or dialogue is actually
  visible, or use `report_menu_state` while holding the bad state.
- Main-menu erase/name-entry follow-up: the latest live log showed the erase
  confirmation being treated as `field` on map `0x00`, causing extra dialogue,
  bogus auto-step block logs, and the false "Game started" / "Unknown Map 0"
  path. `state.lua` now keeps erase confirmation and name entry in title state,
  and `main.lua` now suppresses repeated A frames on name entry until a short
  stable release. `report_title_state` can log the visible title rows and
  selected name-grid cell if the issue needs another capture after reload.
- The next input check found that `S` is BizHawk's NES `P1 A` autofire binding,
  while normal A is `X`. Retest name entry and erase confirmation with `X`, not
  `S`; the map announcement after erase likely came from an extra autofire
  confirm into real gameplay.
- Mod hotkeys were regrouped to avoid BizHawk controls: common object actions
  stay on bare keys (`J/K/L/O/U/Q`), info commands use `Shift+key`, diagnostics
  use `Ctrl+key`, freeze NPCs is `Shift+F`, and tile diagnostics is `Ctrl+N`.
- King dialogue regression: after the hotkey/menu fixes, the king's lower
  dialogue was present (`lower_len=97`) but not automatically read because
  `in_gameplay` stayed false after the title-to-field debounce. `main.lua` now
  clears that debounce after "Game started."; the next live log confirmed king
  and NPC dialogue auto-read again.
- Command menu and post-dialogue status polish: command-menu openings now speak
  the highlighted item immediately, such as `Command. TALK`, instead of only
  saying `Command.`. The lower dialogue reader now skips persistent status rows
  like `Bill LV 1 HP 15 MP 0 G 120 E 0`, including hero names with lowercase
  letters, so the status line should not speak after dialogue dismissal.
- Follow-up log evidence showed the remaining status-line speech was coming
  from the upper dialogue reader, not the lower one: `report_upper_dialogue_state`
  showed `upper="Bill LV ..."` and `lower_len=0`. The upper reader now suppresses
  extracted `new_text` fragments that are themselves status text and logs
  `UPPER_DIALOGUE_SUPPRESS_STATUS` when that path is caught.
- BizHawk launchers now support `--state-slot N`; quick slot 1 can be loaded
  with `./launch_dw.sh --state-slot 1` or `./launch_bizhawk.sh --state-slot 1`.
- 2026-05-01 quick live map `0x05` route cycle: from throne-room `(3,4)`,
  object enumeration found 9 objects and the door/stairs data still looked sane
  (`inspect_tile:4,7` = `door_closed`, `inspect_tile:8,8` = `passthrough`).
  Auto-walk reached a nearby chest and then Guard 3. The Guard 3 route first
  logged `NEW BLOCK` for `(4,4)` down into `(4,5)`, but a controlled
  `probe_edge:DOWN` from `(4,4)` moved successfully, changing the seam evidence
  to noisy/transient rather than a confirmed map blocker.
- The same cycle found player-facing hitch risk in debug commands, not focused
  route execution: `report_path_state`, `inspect_move`, explicit
  `pathfind_adjacent`, and `probe_edge` all produced roughly 1-1.7 second
  `CMD_TIMING` lines. The focused Guard 3 auto-walk window itself reported
  `objects.check_refresh max_ms=0`, `auto_step.update max_ms=1`, and
  `debug_tools.tick max_ms=2`.
- 2026-05-05 crash during live play: `dw_debug.log` reset to a bare header and
  `dw_script_error.log` showed `snapshot.update: 69` from BizHawk
  `mainmemory.read_u8` during `game_snapshot.update`. The memory adapter now
  catches direct RAM API errors and falls back to `System Bus`, but because the
  script was already dead, this still needs a manual BizHawk script reload or
  emulator relaunch before gameplay retest.
- 2026-05-05 King dialogue glitch: the line was spoken as
  `greatly pleased 'I am thou hast that rned, Bill. retu`. Logs confirmed the
  same scrambled string in `EVENT: dialogue`, so the speech backend was not at
  fault. The fix teaches the PPU text reader to assemble rows in visible screen
  order using horizontal scroll plus the active nametable bit. Retest after a
  manual script reload: TALK to the King should read the sentence in normal
  order, starting with `I am greatly pleased...`.
- 2026-05-09 B1 auto-walk timing follow-up: the noisy return-route reroutes
  were partly false route-executor timeouts caused by early movement-subpixel
  twitches, not new engine blockers. After the autowalk timing patch, a clean
  live B1 pass from entrance to stairs reached `(9,9)` with only the known
  `(6,3).west` direct-retry failure, and the return route reached `(0,0)`
  without blocked events or runtime blockers.

Recommended next step:
- The narrow Brecconary exit target is now clean after the autostep timing
  patch. A full parked-NPC object survey from `(15,15)` is the next useful
  confidence check before moving on to broader playtesting.
- Continue real early-game playtesting from the FCEUX path. Good next targets
  are combat narration, shops/inns, item/spell flows, and any remaining menu or
  dialogue polish that shows up naturally. If the post-dialogue status row
  appears again, check for `UPPER_DIALOGUE_SUPPRESS_STATUS` and
  `report_upper_dialogue_state` before changing the dialogue parser again.
- Future Erdrick's Cave B2 polish task: revisit the chest-to-stairs return route
  from chest-adjacent `(8,3)` to B2 stairs `(8,9)` when pathfinding cleanup is
  back in scope. Use direct verifiers/probes on the return-trip bounce
  candidates before changing permanent map data; the current route is playable
  and should not block the pivot to combat/dialogue work.
- While testing object navigation, rapidly tap J/L and listen for reduced audio
  hitching. Use K to speak the current selection immediately. If the short delay
  feels worse than the old behavior, set `object_nav_speech_coalesce_frames=0`
  in `dw_access.ini` and reload the script.
- Keep BizHawk audio/throttle tuning as historical debug context only. Do not
  spend normal playtesting cycles there unless a BizHawk-specific task is
  requested.
- If a BizHawk-specific lag experiment is requested later, compare one clean
  repro at a time with `reset_scan_stats` / `report_scan_stats`, fresh
  `CMD_TIMING` lines, and fresh `ROUTE_PLAN_TIMING` lines.
- Retest manual movement overshoot in normal play. The route executor now
  clears injected D-pad after movement starts, but manual cell-jumping still
  needs the user's hands-on confirmation.
- Retest auto-walk from quick slot 1 without pressing it immediately after
  launch. Use `current_object` first; if it says "No objects found", wait for
  the deferred object refresh, then select the target and try `O` / `U`.
- If auto-walk still feels choppy after objects are populated, capture
  `reset_scan_stats`, exactly one `auto_walk`, then `report_scan_stats`. A
  fresh `objects.check_refresh max_ms=...` line matters most if the hitch
  happens at route completion/cancel; `ROUTE_PLAN_TIMING` still matters if the
  hitch happens before movement starts.
- If the throne-room `(4,4)->(4,5)` route block appears again, do not promote it
  to map data from a single auto-walk. Reprobe with `probe_edge:DOWN` from
  `(4,4)` and compare against the latest noisy evidence.

## 2026-07-09 Cantlin Merchant 5/6 Follow-Up

- Merchant 5 at `(2,12)` is now a non-service `Radish Merchant`, not an
  essential shop/inn route target. After the west-shop blockers were modeled,
  `debug_pathfind_adjacent_skip_npcs:2,12` still had no public adjacent path
  and `debug_route_frontier_skip_npcs:2,13,30` found
  `hidden_bridge_candidates=0`. A live TALK probe from `(4,12)` facing west
  produced only the radish dialogue: `Come buy my radishes! They are fresh and
  cheap. Buy thy radishes today!`
- Promoted additional same-origin `probe_edge_verify:...,3` Cantlin blockers:
  Merchant 5 west-pocket edges `(5,15).west`, `(5,16).east/south/west`,
  `(5,18).north`, `(6,15).south`, `(6,18).north/south`,
  `(7,15).south`, `(7,18).north/south`, `(8,15).east`,
  `(8,16).east/west`, `(8,17).east/west`, and `(8,18).south`; Merchant 6
  route edges `(14,11).east`, `(7,11).north/west`, `(15,12).north`,
  `(8,12).east`, `(8,11).east`, `(8,13).east/south`, `(6,11).north/west`,
  `(7,13).south`, `(6,12).west`, and `(6,13).west/south`.
- Merchant 6 at `(7,12)` is now the live-confirmed `Tool Merchant`. Adjacent
  routing has no public path after the verified blockers above, and
  `debug_route_frontier_skip_npcs:7,12,40` found no hidden bridge into the
  adjacent pocket. Counter probes found `(9,12)` facing west and `(7,14)`
  facing north both produce `There is no one there`; `(5,12)` facing east
  opens the tool-shop prompt: `Welcome. We deal in tools. What can I do for
  thee?` Route the Tool Merchant service to `(5,12)` facing east.
- Current live stop: Cantlin `(5,12)`, NPCs frozen, command menu closed, no
  lower/merchant dialogue active, runtime overlay `RUNTIME_BLOCKS map=0x0A
  count=5` for the newest source-only Merchant 6 edges.
- Source fix: `field_action_guard.lua` now receives `dialogue_text` from
  `main.lua` and ignores passive status/name fragments classified by
  `text.is_passive_field_status_noise`; `text.lua` now treats short
  digit-prefixed name fragments such as `16Bill` as passive field status
  noise. A follow-up upper-dialogue fix also prevents lower dialogue plus
  stale command/status overlays such as `COMMAND BillTALK ... LV 16` from
  becoming the processed upper-dialogue marker. Reload `main.lua` before
  relying on the new blocker, object-label, or text-guard source changes.

When adding issues, use this format:
- ID
- Severity
- Area
- Description
- Reproduction steps
- Observed behavior
- Expected behavior
- Evidence or relevant log lines

## Useful Commands

State and speech:
- `speech_status`
- `log_state`
- `report_position`
- `current_object`
- `reset_scan_stats`
- `report_scan_stats`

Object navigation:
- `next_object`
- `prev_object`
- `next_filter`
- `pathability_filter`
- `pathfind_adjacent:X,Y`
- `auto_walk`

Path/debug recovery:
- `report_path_state`
- `inspect_tile:X,Y`
- `inspect_move:DIR`
- `report_runtime_blocks`
