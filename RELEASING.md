# Releasing LM15.jl

## What 1.0.0 was checked with

Re-checked 2026-10-06 at contract `0f3ea82`, when the pending registration moved again,
to the commit that carries the SSE size fix (INV-056) and the tool-description fix
(MAP-17): `Pkg.test()` (Julia 1.12) and the contract, 1,901 of 1,901; a 30 MB image line
over local HTTP (intact, 1.7 s after the first call); live, `openai:gpt-4.1-mini` streamed
through the router with a 74 KB system prompt ("OK"; the 2026-09-30 commit refuses it with
"SSE line exceeds configured limit").

Re-checked 2026-09-30 at contract `57e33d1`, when the pending registration moved to the
commit that carries the Claude Code and `max_tokens` changes: `Pkg.test()` (Julia 1.12)
and the contract, 1,838 of 1,838. The rest below is from 2026-09-26, at 1,788 checks;
the cross-language runs and live smoke were not repeated.


```bash
julia --project=. -e 'using Pkg; Pkg.test()'                           # Julia 1.12.7 and 1.10.12
cd ../lm15-contract && python3 harness/check.py --shim julia --direction all   # 1,788 of 1,788, at the pin
python3 tools/managed_crossrun.py python julia typescript rust go      # 40 of 40
cd ../lm15-jl && bash docs/build.sh                                     # the manual, no network
set -a; . ../.env; set +a; julia --project=. examples/live_smoke.jl receipts/2026-09-26-live-smoke --managed
python3 ../lm15-contract/tools/check_secrecy.py --root receipts/2026-09-26-live-smoke
```

## Registering in Julia's General registry

1. Push `main` with the release commit; CI green (tests on three OSes and two Julia
   versions, the contract job, the lowest-compatible-versions job, the docs build).
2. On the release commit, comment `@JuliaRegistrator register` (the Registrator GitHub
   app must be installed on the repository). TagBot then tags `v1.0.0`.
3. **The name needs a human reviewer.** The registry's automatic merge refuses `LM15` on
   three name rules: shorter than 5 characters, all capitals, and close to `LMDB` and
   `MD5`. Registration still works, but the pull request waits for a registry
   maintainer; explain there that `lm15` is the project's name in every language
   (Python `lm15`, npm `@lm15/lm15`, crates.io `lm15`, Go `lm15-go`). Renaming the
   Julia package instead would change `using LM15` for every user and is a product
   decision, not a packaging one.

Later releases: bump `version` in `Project.toml`, update `CHANGELOG.md`, move
`CONTRACT_PIN` in the same commit as the code that needed it, and register again.
