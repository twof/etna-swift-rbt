// RBT validity predicate + properties + reference "model" list operations,
// ported from ETNA's reference workload (jwshii/etna `Spec.v`, mirrored by
// alpaylan/etna-rust-rbt `src/spec.rs`).
//
// Properties return `Bool?` (mirroring the Rust port's `Option<bool>`):
//   - `true`  → property held
//   - `false` → property violated (a real counterexample)
//   - `nil`   → discarded (precondition failed, OR a `delete` returned `nil` on
//                a property that propagates it as a discard).
//
// `delete` returning `nil` is handled ASYMMETRICALLY, faithfully to the Rust
// port: `delete_valid/post/model` and `insert_delete` discard (the `?`
// short-circuit), while `delete_insert` and `delete_delete` treat it as a
// counterexample (`false`). See `etna-rs-utils` `Implies` + `spec.rs`.

// MARK: - Validity predicate (isRBT = isBST ∧ consistentBlackHeight ∧ noRedRed)

func every(_ p: (Int) -> Bool, _ t: Tree) -> Bool {
    switch t {
    case .E:
        return true
    case let .T(_, a, x, _, b):
        return p(x) && every(p, a) && every(p, b)
    }
}

public func isBST(_ t: Tree) -> Bool {
    switch t {
    case .E:
        return true
    case let .T(_, a, x, _, b):
        // Difference from SmallCheck: don't allow repeated keys.
        return every({ $0 < x }, a) && every({ $0 > x }, b) && isBST(a) && isBST(b)
    }
}

func blackRoot(_ t: Tree) -> Bool {
    switch t {
    case .T(.R, _, _, _, _):
        return false
    default:
        return true
    }
}

/// "No red node has a red parent."
public func noRedRed(_ t: Tree) -> Bool {
    switch t {
    case .E:
        return true
    case let .T(.B, a, _, _, b):
        return noRedRed(a) && noRedRed(b)
    case let .T(.R, a, _, _, b):
        return blackRoot(a) && blackRoot(b) && noRedRed(a) && noRedRed(b)
    }
}

/// "Every path from the root to an empty node contains the same number of
/// black nodes."
public func consistentBlackHeight(_ t: Tree) -> Bool {
    func go(_ t: Tree) -> (Bool, Int) {
        switch t {
        case .E:
            return (true, 1)
        case let .T(rb, a, _, _, b):
            let (aBool, aHeight) = go(a)
            let (bBool, bHeight) = go(b)
            let isBlack = rb == .B ? 1 : 0
            return (aBool && bBool && aHeight == bHeight, aHeight + isBlack)
        }
    }
    return go(t).0
}

public func isRBT(_ t: Tree) -> Bool {
    isBST(t) && consistentBlackHeight(t) && noRedRed(t)
}

// MARK: - Model (sorted-association-list) operations

public func toList(_ t: Tree) -> [(Int, Int)] {
    switch t {
    case .E:
        return []
    case let .T(_, l, k, v, r):
        return toList(l) + [(k, v)] + toList(r)
    }
}

func deleteKey(_ k: Int, _ l: [(Int, Int)]) -> [(Int, Int)] {
    l.filter { $0.0 != k }
}

// Ported from `spec.rs` `l_insert` (recursive insert into a sorted list).
func lInsert(_ kv: (Int, Int), _ l: [(Int, Int)]) -> [(Int, Int)] {
    guard let (k, v) = l.first else { return [kv] }
    if kv.0 == k {
        return [kv] + Array(l.dropFirst())
    } else if kv.0 < k {
        return [kv] + l
    } else {
        return [(k, v)] + lInsert(kv, Array(l.dropFirst()))
    }
}

func listsEqual(_ a: [(Int, Int)], _ b: [(Int, Int)]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { $0 == $1 }
}

// MARK: - Properties

public func prop_insert_valid(_ t: Tree, _ k: Int, _ v: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    return isRBT(insert(k, v, t))
}

public func prop_delete_valid(_ t: Tree, _ k: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    guard let t2 = delete(k, t) else { return nil }   // None → discard (Rust `?`)
    return isRBT(t2)
}

public func prop_insert_post(_ t: Tree, _ k: Int, _ k2: Int, _ v: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    let expected: Int? = (k == k2) ? v : find(k2, t)
    return find(k2, insert(k, v, t)) == expected
}

public func prop_delete_post(_ t: Tree, _ k: Int, _ k2: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    guard let t2 = delete(k, t) else { return nil }   // None → discard (Rust `?`)
    let expected: Int? = (k == k2) ? nil : find(k2, t)
    return find(k2, t2) == expected
}

public func prop_insert_model(_ t: Tree, _ k: Int, _ v: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    return listsEqual(toList(insert(k, v, t)), lInsert((k, v), deleteKey(k, toList(t))))
}

public func prop_delete_model(_ t: Tree, _ k: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    guard let t2 = delete(k, t) else { return nil }   // None → discard (Rust `?`)
    return listsEqual(toList(t2), deleteKey(k, toList(t)))
}

public func prop_insert_insert(_ t: Tree, _ k: Int, _ kp: Int, _ v: Int, _ vp: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    let t1 = insert(k, v, t)
    let t2 = insert(kp, vp, insert(k, v, t))
    return listsEqual(toList(insert(k, v, insert(kp, vp, t))), toList(k == kp ? t1 : t2))
}

// Ported from the trusted Coq `prop_InsertDelete` (jwshii/etna `Spec.v`), which
// differs from the etna-rust port: the relation is `insert k v (delete kp t)`
// on the LHS (insert-into-deleted), and `None => Some false`. The Rust port
// instead computes `delete kp (insert k v t)` on the LHS — a transposition that
// makes the trivial `(E 0 0 0)` input fail on the *clean* code, so its upstream
// witness for this property is spurious. We follow the Coq oracle.
public func prop_insert_delete(_ t: Tree, _ k: Int, _ kp: Int, _ v: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    guard let tPrime = delete(kp, t) else { return false }   // None → counterexample (Coq)
    if k == kp {
        return listsEqual(toList(insert(k, v, tPrime)), toList(insert(k, v, t)))
    }
    guard let tPP = delete(kp, insert(k, v, t)) else { return false }
    return listsEqual(toList(insert(k, v, tPrime)), toList(tPP))
}

public func prop_delete_insert(_ t: Tree, _ k: Int, _ kp: Int, _ v: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    guard let tp = delete(k, insert(kp, v, t)) else { return false }   // None → counterexample
    guard let tpp = delete(k, t) else { return false }                 // None → counterexample
    let tppp = insert(kp, v, tpp)
    return listsEqual(toList(tp), toList(k == kp ? tpp : tppp))
}

public func prop_delete_delete(_ t: Tree, _ k: Int, _ kp: Int) -> Bool? {
    guard isRBT(t) else { return nil }
    guard let tp = delete(kp, t) else { return false }      // None → counterexample
    guard let tpp = delete(k, tp) else { return false }
    guard let t1p = delete(k, t) else { return false }
    guard let t1pp = delete(kp, t1p) else { return false }
    return listsEqual(toList(tpp), toList(t1pp))
}
