import Testing
@testable import RBT

/// Faithful-port proof against the TRUSTED hand-written 2023 Coq RBT
/// (jwshii/etna) as oracle — see `oracle/coq-rbt/`. Our Swift `evaluate` must
/// match the Coq clean implementation on every witness (all 38 → `true`).
@Suite("Oracle (hand-written Coq RBT)")
struct OracleTests {

    @Test("Swift clean verdicts match the hand-written Coq RBT on all witnesses")
    func matchesCoqOracle() throws {
        for c in coqClean {
            let result = try evaluate(property: c.property, args: witnessArgs(c.input))
            #expect(
                result == c.verdict,
                "\(c.mutant)/\(c.property) on \(c.input): expected \(String(describing: c.verdict)) (Coq), got \(String(describing: result))"
            )
        }
    }

    @Test("S-expr parse + decode round-trips (bare colors)")
    func sExprRoundTrip() throws {
        let tree = try decodeTree(parseSExpr("(T B (T R E 0 0 E) 2 5 E)"))
        #expect(tree == .T(.B, .T(.R, .E, 0, 0, .E), 2, 5, .E))
        #expect(tree.description == "(T B (T R E 0 0 E) 2 5 E)")
    }

    @Test("S-expr decoder accepts parenthesized (E)/(B)/(R) spelling")
    func sExprParenSpelling() throws {
        let tree = try decodeTree(parseSExpr("(T (B) (E) 0 0 (E))"))
        #expect(tree == .T(.B, .E, 0, 0, .E))
    }

    @Test("isRBT basics")
    func isRBTBasics() {
        #expect(isRBT(.E))
        // A single black node is a valid RBT.
        #expect(isRBT(.T(.B, .E, 0, 0, .E)))
        // Red root is fine for noRedRed/blackHeight but must still be a BST.
        #expect(!isRBT(.T(.B, .E, 1, 0, .T(.R, .E, 0, 0, .E))))   // BST violation
        // Red-red violation.
        #expect(!isRBT(.T(.R, .T(.R, .E, 0, 0, .E), 1, 0, .E)))
    }
}
