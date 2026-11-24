# Map artwork description package - 2026-10-29

Candidate version: `2026.10.29-qualification1`. Description implementation commit:
`90e50d099797d7b6094800149a704f5bcca9202e`.

## Content and player acceptance

All 28 interior maps have short, spoiler-safe artwork descriptions through
Shift+D and the read-only `describe_map` command. Dark dungeons require physical
light. Speech queues without stopping movement. The player accepted Tantegel's
throne room, main floor, and Brecconary on October 28. On October 29 they reported
additional successful checks across multiple Garin's Grave and Charlock floors
and a couple more towns. Exact additional floor IDs and towns were not supplied.
This closes representative listening/content acceptance; special light,
interruption, and continued-auto-walk scenarios were not separately reported.
Source/image review is complete; no full map tour is required.

## Automated qualification

Native Windows `python -u run_tests.py` passed 44 host Lua suites and 82 Python
tests, plus Lua/Python/shell syntax, speech dependency, and command queue checks.
The live-only screen and speech diagnostic scripts remain excluded.

The new player archive and matching corresponding-source archive use the same
verified FCEUX runtime, portable speech runtime, and pinned dependency sources
as the previous candidate. The player package adds the description module and
key documentation; reference-map images remain development resources.
Artifact sizes, hashes, manifest checks, repeat-build comparison, and extracted
installation checks are recorded in `packaging_qualification_20261029.json`.
Local raw evidence and scripts are under `.test_tmp/descriptions-20261029/`.

The source builder initially refused the existing FCEUX checkout's ownership.
It was retried with a process-only `safe.directory` entry for that exact pinned
checkout. No global Git configuration changed. This was a build-environment
issue, not a source or runtime change.

Clean archived installation and validation-only launch passed in a spaced path,
including repeated install and validation. The Unicode extraction installed the
ROM and clearly refused launch when Windows could not provide an ASCII alias.
These checks did not start an emulator or repeat the separate actual-account
acceptance. Source gameplay acceptance and archived installation checks do not
establish a fresh gameplay smoke pass for these new ZIP bytes.

## Release status

The October 15 and October 23 candidates are preserved. October 23 player/source
archive hashes were independently checked against the recorded qualification
hashes and remain unchanged. No ROM, save, log, or private test state is bundled.

The tester will perform alternate-hardware validation
over the next few days. The user considers the game ready for official release
if that check exposes no issues. Alternate-hardware acceptance and publication
remain pending; no release was created or assets uploaded by this rebuild.
