# etna-swift-rbt

A **red-black tree workload for [ETNA](https://github.com/alpaylan/etna-cli)**,
implemented in **Swift** with **[PropertyTestingKit](https://github.com/doordash-oss/PropertyTestingKit)**
(PTK) as a **coverage-guided** testing strategy.

It is a faithful port of ETNA's reference RBT workload (the hand-written Coq in
[`jwshii/etna`](https://github.com/jwshii/etna) `workloads/Coq/RBT`, mirrored by
[etna-rust-rbt](https://github.com/alpaylan/etna-rust-rbt)): the same colored
`Tree`, the same 10 properties, and the same 13 mutants with the same
ground-truth witnesses. The novelty is the **strategy**: where ETNA's existing
RBT strategies are bespoke/type-based *generators*, here PTK drives the search
with **edge-coverage feedback** — the Swift analog of QuickChick's `FuzzChick`
`TypeBasedFuzzer` (the only coverage-guided strategy in ETNA's current matrix).

This is the sibling of [etna-swift-bst](https://github.com/twof/etna-swift-bst);
RBT is the harder tree workload — deletion goes through Kahrs's
`balLeft`/`balRight`/`join` machinery, and validity is `isBST ∧
consistentBlackHeight ∧ noRedRed`.

## Layout

| Path | Role |
|---|---|
| `Sources/RBT/` | System under test (`Color`, `Tree`, `balance`/`insert`/`delete`/`join`/…), spec (10 properties + `isRBT`), S-expr decoder, and the mutants. No PTK dependency; `-sanitize-coverage` instrumented. |
| `Sources/RBTGen/` | PTK-backed type-based `Tree` generator + per-shape `Codable` argument structs; the coverage-guided `solve(...)` and `sample(...)` strategy. |
| `Sources/Solve/` | The `rbt` executable (ETNA `solve`). Target dir is `Solve`, not `rbt`, to avoid a case-insensitive-filesystem clash with `RBT`. |
| `Sources/rbt-sampler/` | The `rbt-sampler` executable (ETNA `sample`). |
| `Tests/RBTTests/` | Differential oracle: every witness vs the trusted hand-written Coq RBT. |
| `etna.toml`, `steps.json` | ETNA workload manifest + capability protocol. |
| `marauder.toml` | Registers Swift as a marauder custom language. |
| `scripts/` | Toolchain build wrapper + run wrappers + `detect.sh` repro. |
| `oracle/coq-rbt/` | The trusted hand-written Coq oracle (`Impl.v`/`Spec.v`, evaluated with `Compute`). |

## Building & running

PTK requires the **patched Swift toolchain** (parameter packs) and **macOS 26**,
so build via the wrapper rather than system `swift`:

```bash
# Point at your local toolchain build (default shown); Xcode-beta SDK is used.
export BUILD_ROOT=/path/to/OpenSourceDev/build/Ninja-RelWithDebInfoAssert
./scripts/swift-toolchain.sh build      # builds rbt + rbt-sampler
./scripts/swift-toolchain.sh test       # runs the oracle tests
```

`Package.swift` depends on PropertyTestingKit via the **relative path
`../PropertyTestingKit`** (PTK is unreleased and built from a local checkout), so
the PTK checkout must sit beside this workload. Under ETNA the workload is cloned
to `<experiment>/workloads/rbt-swift/`, so symlink PTK next to it:

```bash
ln -s /path/to/PropertyTestingKit <experiment>/workloads/PropertyTestingKit
```

Run the solver (the run wrappers put the toolchain runtime on the dylib path):

```bash
# rbt <strategy> <property> [duration_seconds]   (strategy: "ptk")
./scripts/run-rbt.sh ptk InsertValid 10
# -> {"status":"passed","tests":...,"discards":...,"counterexample":null,...}

./scripts/run-sampler.sh InsertPost 100   # cross-language `sample`: [{time,value},...]
./scripts/detect.sh 8                      # reproduce the source-swap detection sweep
```

`solve` prints one line of ETNA result JSON (`status` ∈ passed | failed | aborted).

## Running under the ETNA CLI

The workload plugs into [`etna`](https://github.com/alpaylan/etna-cli) via
`etna.toml` + `steps.json`. Because Swift isn't one of marauder's built-in
languages, register it via the bundled `marauder.toml` (see [Mutants](#mutants)):

```bash
etna experiment new rbt-eval && cd rbt-eval
etna workload add https://github.com/twof/etna-swift-rbt   # name "rbt-swift"

export BUILD_ROOT=/path/to/OpenSourceDev/build/Ninja-RelWithDebInfoAssert
export MARAUDER_CONFIG="$PWD/workloads/rbt-swift/marauder.toml"   # registers Swift
etna experiment run --tests rbt-swift --params trials=10 --params timeout=60
etna experiment visualize --figure rbt.png                       # task-bucket chart
```

`MARAUDER_CONFIG` must be set: ETNA reads it both at the experiment root (to
accept `language = "Swift"`) and at the workload dir (to locate the `.swift`
mutation variants).

## Mutants

The 13 task mutants are **marauder source-swap variants** inlined at their
mutation points in `Sources/RBT/Tree.swift`: each is a commented-out alternative
body that ETNA's driver activates (`etna mutation set <mutant>`) and recompiles
before fuzzing. This is ETNA's native mutation model — a *task* is one (activated
mutant, property) pair.

| Function | Mutants |
|---|---|
| `insert` / `ins` | `miscolor_insert`, `insert_1`, `insert_2`, `insert_3`, `no_balance_insert_1`, `no_balance_insert_2` |
| `del` | `delete_4`, `delete_5` |
| `balLeft` / `balRight` | `miscolor_balLeft`, `miscolor_balRight` |
| `_join` | `miscolor_join_1`, `miscolor_join_2` |
| `delete` | `miscolor_delete` |

`balance` additionally carries `swap_cd` / `swap_bc` markers (present in the
reference `Impl.v`); like the upstream workload they have no witness tasks, but
they're kept for source fidelity.

Swift isn't a built-in marauder language (Rocq/Haskell/Racket/Rust/OCaml/Python/
Lean), so `marauder.toml` registers it as a custom language (extension `swift`,
`/* */` comments, `|` marker — Swift block comments match Rust's). All mutant
bodies are transcriptions of the reference Coq `Impl.v` / Rust mutant blocks.

## Validation — against the hand-written Coq RBT

The oracle is the **hand-written 2023 Coq RBT** ([`jwshii/etna`](https://github.com/jwshii/etna)),
run via `oracle/coq-rbt/` (the authors' `Impl.v`/`Spec.v` evaluated with
`Compute`). All **38 canonical witnesses** evaluate to `Some true` on the clean
implementation.

- **Faithful port (differential oracle).** Our Swift `evaluate` matches the Coq
  clean verdict on **all 38 witnesses** (`Tests/RBTTests/OracleTests.swift`,
  `CoqFixtures.swift`), exercising both the bare (`B`/`R`/`E`) and parenthesized
  (`(B)`/`(R)`/`(E)`) wire spellings.
- **Mutant fidelity.** Because the mutants are marauder source-swap variants (one
  compiled build per mutant), detection is checked out-of-process by
  `scripts/detect.sh` (activate → rebuild → solve), which is exactly what
  `etna experiment run` does over the (mutant × property) matrix. PTK's coverage-
  guided `solve` finds counterexamples for each — e.g. `miscolor_insert` is caught
  by `InsertValid` in a handful of inputs, returning the upstream witness
  `((T B E 1 0 E) 0 0)`.

### Note: `prop_insert_delete` follows the Coq, not the Rust port

Validating against the Coq oracle surfaced that the **etna-rust port's
`prop_insert_delete` deviates from the trusted Coq `Spec.v`**: the Coq relation
is `insert k v (delete k' t)` on the LHS (insert-into-deleted) with `None =>
Some false`, while the Rust port computes `delete k' (insert k v t)` — a
transposition that makes the trivial input `(E 0 0 0)` fail on the *clean* code.
That bug is why `(E 0 0 0)` appears as an upstream `InsertDelete` witness for five
different mutants (it "catches" them only because the buggy property fails
regardless of mutant). We follow the **Coq** (`Sources/RBT/Spec.swift`), so on the
clean implementation `(E 0 0 0)` correctly evaluates to `true`; the fuzzer finds
genuine `InsertDelete` counterexamples on its own. The upstream witnesses are
preserved verbatim in `etna.toml` for fidelity, but ETNA's `solve` searches
independently and does not depend on them.

`delete` is partial (fuel-bounded; can fail the RB invariants), so it returns
`Tree?`. Following the Coq, `delete` returning `None` is a **counterexample**
(`false`) for `DeleteValid`, `InsertDelete`, `DeleteInsert`, `DeleteDelete`, and a
**discard** (`nil`) for `DeletePost`, `DeleteModel` (whose Coq option-monad
propagates `None` as a discard). On valid RBT inputs the clean `delete` never
fails, so this only affects behavior under mutation.

## Relation to ETNA

ETNA evaluates strategies by **mutation testing**: a *task* is a (mutant,
property) pair, scored by whether a strategy finds the injected bug within a
budget over N trials, visualised as task-bucket charts. This repo contributes a
**Swift + coverage-guided** point on that map for the RBT workload. The
cross-language `sample` capability is open-loop (matches ETNA's serialized-input
runners); the coverage-guided `solve` is necessarily intra-process (the coverage
feedback loop cannot cross the serialization boundary).
