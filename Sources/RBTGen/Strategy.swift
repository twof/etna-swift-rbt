import RBT
import PropertyTestingKit
import Foundation
import os

/// Thrown by the fuzz closure when a property is violated; carries the failing
/// input in ETNA wire form so `solve` can report it as the counterexample.
struct PropertyViolation: Error { let wire: String }

/// Outcome of one solve run, shaped for ETNA's (legacy) result JSON.
public struct SolveOutcome: Sendable {
    public let status: String          // "passed" | "failed" | "aborted"
    public let tests: Int
    public let discards: Int
    public let counterexample: String?
    public let error: String?
    public let timeNs: UInt64

    public init(status: String, tests: Int, discards: Int, counterexample: String?, error: String?, timeNs: UInt64) {
        self.status = status
        self.tests = tests
        self.discards = discards
        self.counterexample = counterexample
        self.error = error
        self.timeNs = timeNs
    }
}

private func jsonEscape(_ s: String) -> String {
    var out = ""
    for c in s {
        switch c {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\n": out += "\\n"
        case "\t": out += "\\t"
        case "\r": out += "\\r"
        default: out.append(c)
        }
    }
    return out
}

extension SolveOutcome {
    /// ETNA result JSON (matching the shape emitted by the Rust/Python workloads).
    public var json: String {
        let cex = counterexample.map { "\"\(jsonEscape($0))\"" } ?? "null"
        let err = error.map { "\"\(jsonEscape($0))\"" } ?? "null"
        return """
        {"status":"\(status)","tests":\(tests),"discards":\(discards),"counterexample":\(cex),"error":\(err),"time":"\(timeNs)ns","execution_time":null,"generation_time":null,"shrinking_time":null}
        """
    }
}

/// Number of parallel fuzz engines. Defaults to the core count (full parallel):
/// the `stop_at_first_counterexample` plugin halts the finding engine, and PTK's
/// `runEngines` then cancels the siblings (cross-engine early-cancel), so `solve`
/// still returns at the first counterexample with time-to-find — now with N
/// engines searching instead of one. Override with `RBT_PARALLELISM` (e.g. `=1`
/// for a single engine).
let enginesParallelism: Int = {
    if let v = ProcessInfo.processInfo.environment["RBT_PARALLELISM"], let n = Int(v), n > 0 { return n }
    return ProcessInfo.processInfo.processorCount
}()

/// Run the coverage-guided fuzzer over inputs of type `I`, checking `check`.
/// `check` returns the property verdict: `false` is a counterexample, `nil` a
/// precondition discard, `true` a pass.
private func runFuzz<I: MutatorProviding & Codable & Sendable>(
    _ type: I.Type,
    duration: Duration,
    coverageStrategy: CoverageStrategy,
    wire: @escaping @Sendable (I) -> String,
    check: @escaping @Sendable (I) -> Bool?
) async -> SolveOutcome {
    let discards = OSAllocatedUnfairLock(initialState: 0)
    let start = DispatchTime.now()
    func elapsed() -> UInt64 { DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds }

    do {
        let result = try await fuzz(
            duration: duration,
            persistence: .ephemeral,
            coverageStrategy: coverageStrategy,
            parallelism: enginesParallelism,
            // Mutation scheduling is PTK's pool scheduler (default
            // .weightedPool()); the bus carries only the stop observer.
            plugins: { [
                .stopOnFirstFailure(reason: .custom("counterexample_found")),
            ] }
        ) { (input: I) in
            switch check(input) {
            case .some(false): throw PropertyViolation(wire: wire(input))
            case .none: discards.withLock { $0 += 1 }
            case .some(true): break
            }
        }
        return SolveOutcome(status: "passed", tests: result.stats.totalInputs,
                            discards: discards.withLock { $0 }, counterexample: nil, error: nil, timeNs: elapsed())
    } catch let e as FuzzError {
        guard case let .testFailed(_, underlying, _, stats) = e else {
            return SolveOutcome(status: "aborted", tests: 0, discards: discards.withLock { $0 },
                                counterexample: nil, error: "\(e)", timeNs: elapsed())
        }
        return SolveOutcome(status: "failed", tests: stats.totalInputs,
                            discards: discards.withLock { $0 },
                            counterexample: (underlying as? PropertyViolation)?.wire, error: nil, timeNs: elapsed())
    } catch {
        return SolveOutcome(status: "aborted", tests: 0, discards: discards.withLock { $0 },
                            counterexample: nil, error: "\(error)", timeNs: elapsed())
    }
}

/// All property names this workload understands (matches `etna.toml`).
public let rbtProperties = [
    "InsertValid", "DeleteValid",
    "InsertPost", "DeletePost",
    "InsertModel", "DeleteModel",
    "InsertInsert", "InsertDelete", "DeleteInsert", "DeleteDelete",
]

public enum SolveError: Error { case unknownProperty(String), unknownStrategy(String) }

/// The PTK coverage strategies this workload exposes as ETNA strategy names.
/// `ptk` stays as a back-compat alias for the default (`.pathTrie`).
public func coverageStrategy(named name: String) throws -> CoverageStrategy {
    switch name {
    case "ptk", "ptk-pathtrie": return .pathTrie
    case "ptk-signaturematch": return .signatureMatch
    case "ptk-newedge": return .newEdge
    case "ptk-hitcountbuckets": return .hitCountBuckets
    default: throw SolveError.unknownStrategy(name)
    }
}

/// Coverage-guided solve: fuzz `property` for `duration` judging novelty with
/// `coverageStrategy`. The mutant under test is whichever marauder variant is
/// active in the compiled `RBT` module.
public func solve(
    property: String,
    duration: Duration,
    coverageStrategy: CoverageStrategy = .pathTrie
) async throws -> SolveOutcome {
    switch property {
    case "InsertValid":
        return await runFuzz(ArgTII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_insert_valid($0.t, $0.k, $0.k2) })
    case "DeleteValid":
        return await runFuzz(ArgTI.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_delete_valid($0.t, $0.k) })
    case "InsertPost":
        return await runFuzz(ArgTIII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_insert_post($0.t, $0.k, $0.k2, $0.v) })
    case "DeletePost":
        return await runFuzz(ArgTII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_delete_post($0.t, $0.k, $0.k2) })
    case "InsertModel":
        return await runFuzz(ArgTII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_insert_model($0.t, $0.k, $0.k2) })
    case "DeleteModel":
        return await runFuzz(ArgTI.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_delete_model($0.t, $0.k) })
    case "InsertInsert":
        return await runFuzz(ArgTIIII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_insert_insert($0.t, $0.k, $0.k2, $0.v, $0.v2) })
    case "InsertDelete":
        return await runFuzz(ArgTIII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_insert_delete($0.t, $0.k, $0.k2, $0.v) })
    case "DeleteInsert":
        return await runFuzz(ArgTIII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_delete_insert($0.t, $0.k, $0.k2, $0.v) })
    case "DeleteDelete":
        return await runFuzz(ArgTII.self, duration: duration, coverageStrategy: coverageStrategy,
                             wire: { $0.wire }, check: { prop_delete_delete($0.t, $0.k, $0.k2) })
    default:
        throw SolveError.unknownProperty(property)
    }
}

// MARK: - Sampling (cross-language `sample` capability)

/// Generate `count` inputs for `property`, each with its generation time (ns)
/// and ETNA wire serialization. Open-loop (no coverage feedback).
public func sample(property: String, count: Int) throws -> [(timeNs: UInt64, wire: String)] {
    func gen<I: MutatorProviding>(_ type: I.Type, _ wire: @escaping (I) -> String) -> [(UInt64, String)] {
        var rng = FastRNG()
        var out: [(UInt64, String)] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            let start = DispatchTime.now()
            let value = I.defaultMutator.generate(&rng)
            let ns = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            out.append((ns, wire(value)))
        }
        return out
    }
    switch property {
    case "DeleteValid", "DeleteModel":
        return gen(ArgTI.self) { $0.wire }
    case "InsertValid", "DeletePost", "InsertModel", "DeleteDelete":
        return gen(ArgTII.self) { $0.wire }
    case "InsertPost", "InsertDelete", "DeleteInsert":
        return gen(ArgTIII.self) { $0.wire }
    case "InsertInsert":
        return gen(ArgTIIII.self) { $0.wire }
    default:
        throw SolveError.unknownProperty(property)
    }
}
