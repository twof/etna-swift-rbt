// Red-black tree implementation, ported from ETNA's reference workload
// (jwshii/etna `workloads/Coq/RBT/Src/Impl.v`, mirrored by alpaylan/etna-rust-rbt
// `src/implementation.rs`, which is based on Okasaki 1999 + Kahrs's deletion).
//
// The clean (correct) bodies are active; the mutants live inline as marauder
// source-swap variants — commented-out alternative bodies that ETNA activates +
// recompiles per task (see README "Mutants"; marauder.toml registers Swift as a
// custom language). Fifteen markers cover the 13 task mutants plus the two
// `balance` mutants (swap_cd / swap_bc), which—like the upstream workload—carry
// no witness tasks but are kept for fidelity to the reference source.
//
// `delete` and `join` are partial (fuel-bounded, can fail the balancing
// invariants), so they return `Tree?` — `nil` is the "no result" of Coq's
// `option Tree`. `insert` is total.

public enum Color: Equatable, Codable, Sendable, CustomStringConvertible {
    case R
    case B
    public var description: String { self == .R ? "R" : "B" }
}

public indirect enum Tree: Equatable, Codable, Sendable {
    case E
    case T(Color, Tree, Int, Int, Tree)
}

extension Tree: CustomStringConvertible {
    /// Canonical ETNA wire form: `E` and `(T <color> <left> <k> <v> <right>)` —
    /// matches the `etna.toml` witness format. (The decoder in `SExpr.swift`
    /// also accepts the parenthesized `(E)`/`(B)`/`(R)` spelling.)
    public var description: String {
        switch self {
        case .E:
            return "E"
        case let .T(c, l, k, v, r):
            return "(T \(c) \(l) \(k) \(v) \(r))"
        }
    }
}

public let FUEL = 10_000

// MARK: - Recoloring helpers

func blacken(_ t: Tree) -> Tree {
    switch t {
    case .E:
        return .E
    case let .T(_, a, x, vx, b):
        return .T(.B, a, x, vx, b)
    }
}

func redden(_ t: Tree) -> Tree? {
    switch t {
    case let .T(.B, a, x, vx, b):
        return .T(.R, a, x, vx, b)
    default:
        return nil
    }
}

// MARK: - Balance

public func balance(_ col: Color, _ tl: Tree, _ key: Int, _ val: Int, _ tr: Tree) -> Tree {
    switch (col, tl, tr) {
    case let (.B, .T(.R, .T(.R, a, x, vx, b), y, vy, c), d):
        /*| balance_cd */
        return .T(.R, .T(.B, a, x, vx, b), y, vy, .T(.B, c, key, val, d))
        /*|| swap_cd */
        /*|
        return .T(.R, .T(.B, a, x, vx, b), y, vy, .T(.B, d, key, val, c))
        */
        /* |*/
    case let (.B, .T(.R, a, x, vx, .T(.R, b, y, vy, c)), d):
        return .T(.R, .T(.B, a, x, vx, b), y, vy, .T(.B, c, key, val, d))
    case let (.B, a, .T(.R, .T(.R, b, y, vy, c), z, vz, d)):
        /*| balance_bc */
        return .T(.R, .T(.B, a, key, val, b), y, vy, .T(.B, c, z, vz, d))
        /*|| swap_bc */
        /*|
        return .T(.R, .T(.B, a, key, val, c), y, vy, .T(.B, b, z, vz, d))
        */
        /* |*/
    case let (.B, a, .T(.R, b, y, vy, .T(.R, c, z, vz, d))):
        return .T(.R, .T(.B, a, key, val, b), y, vy, .T(.B, c, z, vz, d))
    default:
        return .T(col, tl, key, val, tr)
    }
}

// MARK: - Insert

public func insert(_ key: Int, _ val: Int, _ t: Tree) -> Tree {
    func ins(_ x: Int, _ vx: Int, _ s: Tree) -> Tree {
        switch s {
        case .E:
            /*| ins_empty */
            return .T(.R, .E, x, vx, .E)
            /*|| miscolor_insert */
            /*|
            return .T(.B, .E, x, vx, .E)
            */
            /* |*/
        case let .T(rb, a, y, vy, b):
            /*| ins_node */
            if x < y {
                return balance(rb, ins(x, vx, a), y, vy, b)
            } else if y < x {
                return balance(rb, a, y, vy, ins(x, vx, b))
            } else {
                return .T(rb, a, y, vx, b)
            }
            /*|| insert_1 */
            /*|
            return .T(.R, .E, x, vx, .E)
            */
            /*|| insert_2 */
            /*|
            if x < y {
                return balance(rb, ins(x, vx, a), y, vy, b)
            } else {
                return .T(rb, a, y, vx, b)
            }
            */
            /*|| insert_3 */
            /*|
            if x < y {
                return balance(rb, ins(x, vx, a), y, vy, b)
            } else if y < x {
                return balance(rb, a, y, vy, ins(x, vx, b))
            } else {
                return .T(rb, a, y, vy, b)
            }
            */
            /*|| no_balance_insert_1 */
            /*|
            if x < y {
                return .T(rb, ins(x, vx, a), y, vy, b)
            } else if y < x {
                return balance(rb, a, y, vy, ins(x, vx, b))
            } else {
                return .T(rb, a, y, vx, b)
            }
            */
            /*|| no_balance_insert_2 */
            /*|
            if x < y {
                return balance(rb, ins(x, vx, a), y, vy, b)
            } else if y < x {
                return .T(rb, a, y, vy, insert(x, vx, b))
            } else {
                return .T(rb, a, y, vx, b)
            }
            */
            /* |*/
        }
    }
    return blacken(ins(key, val, t))
}

// MARK: - Deletion balancing

func balLeft(_ tl: Tree, _ k: Int, _ v: Int, _ tr: Tree) -> Tree? {
    switch (tl, tr) {
    case let (.T(.R, a, x, vx, b), c):
        return .T(.R, .T(.B, a, x, vx, b), k, v, c)
    case let (bl, .T(.B, a, y, vy, b)):
        return balance(.B, bl, k, v, .T(.R, a, y, vy, b))
    case let (bl, .T(.R, .T(.B, a, y, vy, b), z, vz, c)):
        /*| balLeft */
        guard let cp = redden(c) else { return nil }
        return .T(.R, .T(.B, bl, k, v, a), y, vy, balance(.B, b, z, vz, cp))
        /*|| miscolor_balLeft */
        /*|
        return .T(.R, .T(.B, bl, k, v, a), y, vy, balance(.B, b, z, vz, c))
        */
        /* |*/
    default:
        return nil
    }
}

func balRight(_ tl: Tree, _ k: Int, _ v: Int, _ tr: Tree) -> Tree? {
    switch (tl, tr) {
    case let (a, .T(.R, b, y, vy, c)):
        return .T(.R, a, k, v, .T(.B, b, y, vy, c))
    case let (.T(.B, a, x, vx, b), bl):
        return balance(.B, .T(.R, a, x, vx, b), k, v, bl)
    case let (.T(.R, a, x, vx, .T(.B, b, y, vy, c)), bl):
        /*| balRight */
        guard let ap = redden(a) else { return nil }
        return .T(.R, balance(.B, ap, x, vx, b), y, vy, .T(.B, c, k, v, bl))
        /*|| miscolor_balRight */
        /*|
        return .T(.R, balance(.B, a, x, vx, b), y, vy, .T(.B, c, k, v, bl))
        */
        /* |*/
    default:
        return nil
    }
}

// MARK: - Join

func _join(_ t1: Tree, _ t2: Tree, _ f: Int) -> Tree? {
    if f == 0 { return nil }
    let fp = f - 1
    switch (t1, t2) {
    case (.E, let a):
        return a
    case (let a, .E):
        return a
    case let (.T(.R, a, x, vx, b), .T(.R, c, y, vy, d)):
        switch _join(b, c, fp) {
        case .none:
            return nil
        case let .some(.T(.R, bp, z, vz, cp)):
            /*| join_rr */
            return .T(.R, .T(.R, a, x, vx, bp), z, vz, .T(.R, cp, y, vy, d))
            /*|| miscolor_join_1 */
            /*|
            return .T(.R, .T(.B, a, x, vx, bp), z, vz, .T(.B, cp, y, vy, d))
            */
            /* |*/
        case let .some(bc):
            return .T(.R, a, x, vx, .T(.R, bc, y, vy, d))
        }
    case let (.T(.B, a, x, vx, b), .T(.B, c, y, vy, d)):
        switch _join(b, c, fp) {
        case .none:
            return nil
        case let .some(.T(.R, bp, z, vz, cp)):
            /*| join_bb */
            return .T(.R, .T(.B, a, x, vx, bp), z, vz, .T(.B, cp, y, vy, d))
            /*|| miscolor_join_2 */
            /*|
            return .T(.R, .T(.R, a, x, vx, bp), z, vz, .T(.R, cp, y, vy, d))
            */
            /* |*/
        case let .some(bc):
            return balLeft(a, x, vx, .T(.B, bc, y, vy, d))
        }
    case let (a, .T(.R, b, x, vx, c)):
        guard let tp = _join(a, b, fp) else { return nil }
        return .T(.R, tp, x, vx, c)
    case let (.T(.R, a, x, vx, b), c):
        guard let tp = _join(b, c, fp) else { return nil }
        return .T(.R, a, x, vx, tp)
    }
}

func join(_ t1: Tree, _ t2: Tree) -> Tree? {
    _join(t1, t2, FUEL)
}

// MARK: - Delete

func del(_ x: Int, _ s: Tree, _ f: Int) -> Tree? {
    if f == 0 { return nil }
    let fp = f - 1
    switch s {
    case .E:
        return .E
    case let .T(_, a, y, vy, b):
        /*| del */
        if x < y {
            return delLeft(x, a, y, vy, b, fp)
        } else if y < x {
            return delRight(x, a, y, vy, b, fp)
        } else {
            return join(a, b)
        }
        /*|| delete_4 */
        /*|
        if x < y {
            return del(x, a, fp)
        } else if y < x {
            return del(x, b, fp)
        } else {
            return join(a, b)
        }
        */
        /*|| delete_5 */
        /*|
        if y < x {
            return delLeft(x, a, y, vy, b, fp)
        } else if x < y {
            return delRight(x, a, y, vy, b, fp)
        } else {
            return join(a, b)
        }
        */
        /* |*/
    }
}

func delLeft(_ x: Int, _ dl: Tree, _ dy: Int, _ dvy: Int, _ dr: Tree, _ f: Int) -> Tree? {
    if f == 0 { return nil }
    let fp = f - 1
    switch dl {
    case .T(.B, _, _, _, _):
        guard let tp = del(x, dl, fp) else { return nil }
        return balLeft(tp, dy, dvy, dr)
    default:
        guard let tp = del(x, dl, fp) else { return nil }
        return .T(.R, tp, dy, dvy, dr)
    }
}

func delRight(_ x: Int, _ dl: Tree, _ dy: Int, _ dvy: Int, _ dr: Tree, _ f: Int) -> Tree? {
    if f == 0 { return nil }
    let fp = f - 1
    switch dr {
    case .T(.B, _, _, _, _):
        guard let tp = del(x, dr, fp) else { return nil }
        return balRight(dl, dy, dvy, tp)
    default:
        guard let tp = del(x, dr, fp) else { return nil }
        return .T(.R, dl, dy, dvy, tp)
    }
}

public func delete(_ x: Int, _ t: Tree) -> Tree? {
    /*| delete */
    guard let tp = del(x, t, FUEL) else { return nil }
    return blacken(tp)
    /*|| miscolor_delete */
    /*|
    return del(x, t, FUEL)
    */
    /* |*/
}

// MARK: - Find / Size

public func find(_ x: Int, _ t: Tree) -> Int? {
    switch t {
    case .E:
        return nil
    case let .T(_, l, y, vy, r):
        if x < y {
            return find(x, l)
        } else if y < x {
            return find(x, r)
        } else {
            return vy
        }
    }
}

public func size(_ t: Tree) -> Int {
    switch t {
    case .E:
        return 0
    case let .T(_, l, _, _, r):
        return 1 + size(l) + size(r)
    }
}
