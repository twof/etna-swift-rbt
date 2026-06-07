@testable import RBT

/// Differential fixtures from the TRUSTED oracle: the hand-written 2023 Coq RBT
/// (jwshii/etna), evaluated via `oracle/coq-rbt/`. Each row is (mutant, property,
/// input, clean verdict). These are the canonical ETNA witnesses — counterexamples
/// that catch the named mutant — and on the *clean* implementation every one
/// evaluates to `Some true` (oracle README: "all 38 witnesses → Some true").
///
/// Inputs are in ETNA wire form; colors are bare `B`/`R` (the
/// `miscolor_join_2/DeleteDelete` row uses the parenthesized `(B)`/`(R)`/`(E)`
/// spelling the Rust port emits, exercising both decoder paths).
struct CoqCase {
    let mutant: String
    let property: String
    let input: String
    let verdict: Bool?
    init(_ m: String, _ p: String, _ i: String, _ v: Bool?) {
        mutant = m; property = p; input = i; verdict = v
    }
}

let coqClean: [CoqCase] = [
    // delete_4
    CoqCase("delete_4", "DeleteDelete", "((T B (T B E -1 0 E) 0 3 (T B E 3 0 E)) -1 0)", true),
    CoqCase("delete_4", "DeleteModel", "((T B E 1 0 E) 0)", true),
    CoqCase("delete_4", "DeletePost", "((T B E 0 0 E) 1 0)", true),
    CoqCase("delete_4", "DeleteInsert", "(E 0 1 0)", true),
    CoqCase("delete_4", "InsertDelete", "(E 0 0 0)", true),
    // insert_1
    CoqCase("insert_1", "InsertPost", "((T B E -1 1 E) 0 -1 0)", true),
    CoqCase("insert_1", "InsertModel", "((T B E 1 0 E) 0 0)", true),
    CoqCase("insert_1", "DeleteInsert", "((T B E 0 0 E) -3 -3 0)", true),
    CoqCase("insert_1", "InsertInsert", "(E 0 1 0 0)", true),
    // insert_2
    CoqCase("insert_2", "InsertPost", "((T B E -1 1 E) 0 0 0)", true),
    CoqCase("insert_2", "InsertModel", "((T B E 0 0 E) 1 0)", true),
    CoqCase("insert_2", "InsertDelete", "(E 0 0 0)", true),
    CoqCase("insert_2", "DeleteInsert", "((T B E -1 0 E) 0 0 1)", true),
    CoqCase("insert_2", "InsertInsert", "(E 1 0 1 0)", true),
    // insert_3
    CoqCase("insert_3", "InsertPost", "((T B E 0 1 E) 0 0 0)", true),
    CoqCase("insert_3", "InsertModel", "((T B E -1 1 E) -1 0)", true),
    CoqCase("insert_3", "InsertDelete", "(E 0 0 0)", true),
    CoqCase("insert_3", "InsertInsert", "(E 3 3 0 1)", true),
    // delete_5
    CoqCase("delete_5", "DeleteModel", "((T B (T B E -2 1 E) 0 0 (T B E 1 4 E)) 1)", true),
    CoqCase("delete_5", "DeletePost", "((T B E 3 0 (T R E 4 0 E)) 4 4)", true),
    CoqCase("delete_5", "DeleteDelete", "((T B E -4 6 (T R E 9 0 E)) 9 -4)", true),
    CoqCase("delete_5", "DeleteInsert", "((T B E 0 0 E) 1 1 0)", true),
    // miscolor_insert
    CoqCase("miscolor_insert", "InsertValid", "((T B E 0 0 E) 1 0)", true),
    CoqCase("miscolor_insert", "DeleteInsert", "((T B E 1 0 E) 0 0 0)", true),
    // miscolor_delete
    CoqCase("miscolor_delete", "DeleteValid", "((T B E 0 0 (T R E 1 1 E)) 2)", true),
    // miscolor_balLeft
    CoqCase("miscolor_balLeft", "DeleteValid", "((T B (T B E -5 0 E) 0 0 (T R (T B E 2 2 E) 5 6 (T B E 6 1 E))) -5)", true),
    CoqCase("miscolor_balLeft", "DeleteDelete", "((T B (T B E -2 6 E) -1 0 (T R (T B E 0 0 E) 3 0 (T B E 5 8 E))) 5 -2)", true),
    // miscolor_balRight
    CoqCase("miscolor_balRight", "DeleteValid", "((T B (T R (T B E -8 0 E) -2 0 (T B E 0 0 E)) 6 0 (T B E 7 6 E)) 7)", true),
    CoqCase("miscolor_balRight", "DeleteDelete", "((T B (T R (T B E -9 1 E) -8 0 (T B E 0 0 E)) 3 0 (T B E 6 5 E)) -9 6)", true),
    // miscolor_join_1
    CoqCase("miscolor_join_1", "DeleteValid", "((T B (T B (T R (T B E -12 2 E) -6 0 (T B E -3 0 E)) -2 0 (T R (T B (T R E 0 0 E) 3 0 E) 4 0 (T B E 5 4 E))) 6 3 (T B (T B E 8 8 E) 9 0 (T B E 10 0 E))) -2)", true),
    // miscolor_join_2
    CoqCase("miscolor_join_2", "DeleteValid", "((T B (T B E -5 0 (T R E -4 1 E)) -1 0 (T B (T R E 2 0 E) 4 0 E)) -1)", true),
    CoqCase("miscolor_join_2", "DeleteDelete", "((T (B) (T (B) (E) 0 0 (E)) 1 0 (T (R) (T (B) (E) 2 0 (T (R) (E) 3 0 (E))) 4 0 (T (B) (E) 5 0 (E)))) 4 0)", true),
    // no_balance_insert_1
    CoqCase("no_balance_insert_1", "InsertValid", "((T B (T R E 1 1 E) 2 2 E) 0 0)", true),
    CoqCase("no_balance_insert_1", "DeleteInsert", "((T B (T R (T B E -8 0 E) 0 0 (T B E 1 0 (T R E 4 2 E))) 5 3 (T B E 7 4 E)) 7 2 0)", true),
    CoqCase("no_balance_insert_1", "InsertDelete", "(E 0 0 0)", true),
    // no_balance_insert_2
    CoqCase("no_balance_insert_2", "InsertValid", "((T B E -1 0 E) 0 0)", true),
    CoqCase("no_balance_insert_2", "DeleteInsert", "((T B E 0 0 E) 3 3 0)", true),
    CoqCase("no_balance_insert_2", "InsertDelete", "(E 0 0 0)", true),
]
