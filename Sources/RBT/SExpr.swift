// S-expression decoding for ETNA's serialized input format
//   color := "B" | "R" | "(B)" | "(R)"
//   tree  := "E" | "(E)" | "(T" <color> <tree> <int> <int> <tree> ")"
//   tuple := "(" <arg> ... ")"
// e.g. the witness `((T B E -1 1 E) 0 -1 0)` is a 4-tuple whose first element is
// a tree. This is the wire format the language-agnostic runners consume, and the
// form `etna.toml` witnesses are written in. The decoder accepts both the bare
// (`B`/`R`/`E`) and parenthesized (`(B)`/`(R)`/`(E)`) spellings — the canonical
// witnesses use bare, the Rust port emits parenthesized.

public enum SExpr: Equatable {
    case atom(String)
    case list([SExpr])
}

public enum DecodeError: Error, CustomStringConvertible {
    case malformed(String)

    public var description: String {
        switch self {
        case let .malformed(m): return "malformed S-expr: \(m)"
        }
    }
}

private func tokenize(_ s: String) -> [String] {
    var tokens: [String] = []
    var current = ""
    func flush() {
        if !current.isEmpty {
            tokens.append(current)
            current = ""
        }
    }
    for ch in s {
        switch ch {
        case "(", ")":
            flush()
            tokens.append(String(ch))
        case " ", "\t", "\n", "\r":
            flush()
        default:
            current.append(ch)
        }
    }
    flush()
    return tokens
}

private func parse(_ tokens: inout ArraySlice<String>) throws -> SExpr {
    guard let head = tokens.first else {
        throw DecodeError.malformed("unexpected end of input")
    }
    tokens = tokens.dropFirst()
    switch head {
    case "(":
        var elements: [SExpr] = []
        while let next = tokens.first, next != ")" {
            elements.append(try parse(&tokens))
        }
        guard tokens.first == ")" else {
            throw DecodeError.malformed("missing closing paren")
        }
        tokens = tokens.dropFirst()
        return .list(elements)
    case ")":
        throw DecodeError.malformed("unexpected closing paren")
    default:
        return .atom(head)
    }
}

public func parseSExpr(_ s: String) throws -> SExpr {
    var tokens = tokenize(s)[...]
    let result = try parse(&tokens)
    guard tokens.isEmpty else {
        throw DecodeError.malformed("trailing tokens: \(Array(tokens))")
    }
    return result
}

/// Parse a witness string into its tuple of argument S-exprs.
public func witnessArgs(_ s: String) throws -> [SExpr] {
    switch try parseSExpr(s) {
    case let .list(elements):
        return elements
    case let atom:
        return [atom]
    }
}

// MARK: - Typed decoders

public func decodeColor(_ e: SExpr) throws -> Color {
    switch e {
    case .atom("B"), .list([.atom("B")]):
        return .B
    case .atom("R"), .list([.atom("R")]):
        return .R
    default:
        throw DecodeError.malformed("not a color: \(e)")
    }
}

public func decodeTree(_ e: SExpr) throws -> Tree {
    switch e {
    case .atom("E"):
        return .E
    case let .list(items):
        if items == [.atom("E")] {
            return .E
        }
        guard items.count == 6, items[0] == .atom("T") else {
            throw DecodeError.malformed("not a tree node: \(e)")
        }
        return .T(
            try decodeColor(items[1]),
            try decodeTree(items[2]),
            try decodeInt(items[3]),
            try decodeInt(items[4]),
            try decodeTree(items[5])
        )
    default:
        throw DecodeError.malformed("not a tree: \(e)")
    }
}

public func decodeInt(_ e: SExpr) throws -> Int {
    guard case let .atom(s) = e, let n = Int(s) else {
        throw DecodeError.malformed("not an int: \(e)")
    }
    return n
}

// MARK: - Property dispatch

/// Evaluate a named property against a decoded argument tuple.
/// Returns `nil` when the input is discarded.
public func evaluate(property: String, args: [SExpr]) throws -> Bool? {
    func tree(_ i: Int) throws -> Tree { try decodeTree(args[i]) }
    func int(_ i: Int) throws -> Int { try decodeInt(args[i]) }

    switch property {
    case "InsertValid":
        return prop_insert_valid(try tree(0), try int(1), try int(2))
    case "DeleteValid":
        return prop_delete_valid(try tree(0), try int(1))
    case "InsertPost":
        return prop_insert_post(try tree(0), try int(1), try int(2), try int(3))
    case "DeletePost":
        return prop_delete_post(try tree(0), try int(1), try int(2))
    case "InsertModel":
        return prop_insert_model(try tree(0), try int(1), try int(2))
    case "DeleteModel":
        return prop_delete_model(try tree(0), try int(1))
    case "InsertInsert":
        return prop_insert_insert(try tree(0), try int(1), try int(2), try int(3), try int(4))
    case "InsertDelete":
        return prop_insert_delete(try tree(0), try int(1), try int(2), try int(3))
    case "DeleteInsert":
        return prop_delete_insert(try tree(0), try int(1), try int(2), try int(3))
    case "DeleteDelete":
        return prop_delete_delete(try tree(0), try int(1), try int(2))
    default:
        throw DecodeError.malformed("unknown property: \(property)")
    }
}
