import RBT
import PropertyTestingKit

// MARK: - Building blocks

/// Small integer mutator for the key/value arguments. (Range tuning is a
/// legitimate strategy knob; cf. ETNA §4.2 on sized generation.)
let smallInt = Mutator<Int>(
    seeds: [-2, -1, 0, 1, 2, 3],
    mutate: { v, rng in
        let candidates = [v &+ 1, v &- 1, 0, 0 &- v]
        return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
    },
    // Range matches the tree-key range so a delete/find key argument lands on an
    // existing node often enough to exercise the deletion-rebalancing paths.
    generate: { rng in Int.random(in: -12...12, using: &rng) }
)

func flip(_ c: Color) -> Color { c == .R ? .B : .R }

// MARK: - Clean valid-RBT builder (generation only)

// A clean RBT `insert`/`balance`, kept INDEPENDENT of the SUT in `RBT` (which
// carries the source-swap mutants). Building seed trees with the SUT under
// mutation would be circular and would yield invalid trees that the `isRBT`
// precondition discards — starving the search, which is why the early
// type-based colored-tree generator failed to reach the deletion-rebalancing
// mutants. This generator-local builder guarantees valid RBT inputs regardless
// of which mutant is active, the same idea as ETNA's bespoke generators.
private func gBalance(_ col: Color, _ tl: Tree, _ key: Int, _ val: Int, _ tr: Tree) -> Tree {
    switch (col, tl, tr) {
    case let (.B, .T(.R, .T(.R, a, x, vx, b), y, vy, c), d):
        return .T(.R, .T(.B, a, x, vx, b), y, vy, .T(.B, c, key, val, d))
    case let (.B, .T(.R, a, x, vx, .T(.R, b, y, vy, c)), d):
        return .T(.R, .T(.B, a, x, vx, b), y, vy, .T(.B, c, key, val, d))
    case let (.B, a, .T(.R, .T(.R, b, y, vy, c), z, vz, d)):
        return .T(.R, .T(.B, a, key, val, b), y, vy, .T(.B, c, z, vz, d))
    case let (.B, a, .T(.R, b, y, vy, .T(.R, c, z, vz, d))):
        return .T(.R, .T(.B, a, key, val, b), y, vy, .T(.B, c, z, vz, d))
    default:
        return .T(col, tl, key, val, tr)
    }
}

private func gBlacken(_ t: Tree) -> Tree {
    if case let .T(_, a, x, vx, b) = t { return .T(.B, a, x, vx, b) }
    return .E
}

func gInsert(_ key: Int, _ val: Int, _ t: Tree) -> Tree {
    func ins(_ x: Int, _ vx: Int, _ s: Tree) -> Tree {
        switch s {
        case .E:
            return .T(.R, .E, x, vx, .E)
        case let .T(rb, a, y, vy, b):
            if x < y { return gBalance(rb, ins(x, vx, a), y, vy, b) }
            else if y < x { return gBalance(rb, a, y, vy, ins(x, vx, b)) }
            else { return .T(rb, a, y, vx, b) }
        }
    }
    return gBlacken(ins(key, val, t))
}

/// A valid-by-construction RBT: fold a clean `gInsert` over a random key/value
/// sequence (size scaling with `depth`).
func genTree(_ rng: inout FastRNG, _ depth: Int) -> Tree {
    // Larger key range + more inserts → bushier trees, so deletion reaches the
    // deep `_join` red-red rebalancing case that the hardest mutant lives in.
    let n = Int.random(in: 0...max(1, depth * 4), using: &rng)
    var t: Tree = .E
    for _ in 0..<n {
        t = gInsert(Int.random(in: -12...12, using: &rng), Int.random(in: 0...3, using: &rng), t)
    }
    return t
}

func mutateTree(_ t: Tree, _ rng: inout FastRNG) -> Tree {
    let candidates: [Tree]
    switch t {
    case .E:
        candidates = [gInsert(0, 0, .E), gInsert(1, 0, .E), gInsert(-1, 0, .E)]
    case let .T(c, l, k, v, r):
        candidates = [
            gInsert(k &+ 1, 0, t),         // valid-preserving: insert a fresh key
            gInsert(k &- 1, 0, t),
            gInsert(k, v &+ 1, t),         // valid-preserving: update a value
            .T(flip(c), l, k, v, r),       // structural: recolor (may invalidate)
            .T(c, l, k, v &+ 1, r),
            l, r,                          // structural: drop a side
            .T(c, r, k, v, l),             // structural: swap children
        ]
    }
    guard !candidates.isEmpty else { return t }
    return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
}

/// A type-based tree generator (arbitrary colored trees, not valid-by-
/// construction RBTs), making PTK's strategy the coverage-guided-fuzzer analog
/// of FuzzChick's `TypeBasedFuzzer` rather than a bespoke valid-RBT generator.
extension Tree: MutatorProviding {
    public static var defaultMutator: Mutator<Tree> {
        Mutator(
            seeds: [
                .E,
                .T(.B, .E, 0, 0, .E),
                .T(.B, .T(.R, .E, 0, 0, .E), 1, 0, .T(.R, .E, 2, 0, .E)),
                .T(.B, .E, 1, 0, .T(.R, .E, 2, 0, .E)),
            ],
            mutate: { mutateTree($0, &$1) },
            generate: { genTree(&$0, 4) },
            // Real REDUCE/eviction size metric: wire length.
            size: { $0.description.count }
        )
    }
}

// MARK: - Per-shape argument tuples (single Codable inputs for `fuzz`)

struct ArgTI: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int
    var wire: String { "(\(t) \(k))" }
    static var defaultMutator: Mutator<ArgTI> {
        Mutator(seeds: [ArgTI(t: .E, k: 0)],
                mutate: { x, rng in
                    // Pick ONE field to mutate (weights match the old candidate counts).
                    switch Int.random(in: 0..<4, using: &rng) {
                    case 0, 1: return ArgTI(t: mutateTree(x.t, &rng), k: x.k)
                    default: return ArgTI(t: x.t, k: smallInt.mutate(x.k, &rng))
                    }
                },
                generate: { ArgTI(t: genTree(&$0, 4), k: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int
    var wire: String { "(\(t) \(k) \(k2))" }
    static var defaultMutator: Mutator<ArgTII> {
        Mutator(seeds: [ArgTII(t: .E, k: 0, k2: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<4, using: &rng) {
                    case 0, 1: return ArgTII(t: mutateTree(x.t, &rng), k: x.k, k2: x.k2)
                    case 2: return ArgTII(t: x.t, k: smallInt.mutate(x.k, &rng), k2: x.k2)
                    default: return ArgTII(t: x.t, k: x.k, k2: smallInt.mutate(x.k2, &rng))
                    }
                },
                generate: { ArgTII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTIII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int; var v: Int
    var wire: String { "(\(t) \(k) \(k2) \(v))" }
    static var defaultMutator: Mutator<ArgTIII> {
        Mutator(seeds: [ArgTIII(t: .E, k: 0, k2: 0, v: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<5, using: &rng) {
                    case 0, 1: return ArgTIII(t: mutateTree(x.t, &rng), k: x.k, k2: x.k2, v: x.v)
                    case 2: return ArgTIII(t: x.t, k: smallInt.mutate(x.k, &rng), k2: x.k2, v: x.v)
                    case 3: return ArgTIII(t: x.t, k: x.k, k2: smallInt.mutate(x.k2, &rng), v: x.v)
                    default: return ArgTIII(t: x.t, k: x.k, k2: x.k2, v: smallInt.mutate(x.v, &rng))
                    }
                },
                generate: { ArgTIII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0), v: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}

struct ArgTIIII: Codable, Sendable, MutatorProviding {
    var t: Tree; var k: Int; var k2: Int; var v: Int; var v2: Int
    var wire: String { "(\(t) \(k) \(k2) \(v) \(v2))" }
    static var defaultMutator: Mutator<ArgTIIII> {
        Mutator(seeds: [ArgTIIII(t: .E, k: 0, k2: 0, v: 0, v2: 0)],
                mutate: { x, rng in
                    switch Int.random(in: 0..<6, using: &rng) {
                    case 0, 1: return ArgTIIII(t: mutateTree(x.t, &rng), k: x.k, k2: x.k2, v: x.v, v2: x.v2)
                    case 2: return ArgTIIII(t: x.t, k: smallInt.mutate(x.k, &rng), k2: x.k2, v: x.v, v2: x.v2)
                    case 3: return ArgTIIII(t: x.t, k: x.k, k2: smallInt.mutate(x.k2, &rng), v: x.v, v2: x.v2)
                    case 4: return ArgTIIII(t: x.t, k: x.k, k2: x.k2, v: smallInt.mutate(x.v, &rng), v2: x.v2)
                    default: return ArgTIIII(t: x.t, k: x.k, k2: x.k2, v: x.v, v2: smallInt.mutate(x.v2, &rng))
                    }
                },
                generate: { ArgTIIII(t: genTree(&$0, 4), k: smallInt.generate(&$0), k2: smallInt.generate(&$0), v: smallInt.generate(&$0), v2: smallInt.generate(&$0)) },
                size: { $0.wire.count })
    }
}
