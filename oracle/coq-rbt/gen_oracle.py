import re, sys

toml = open("/tmp/etna-rust-rbt/etna.toml").read()

# Parse: track current mutation block, collect (mut, prop, input)
rows = []
cur_mut = None
for line in toml.splitlines():
    m = re.search(r'mutations\s*=\s*\["([^"]+)"\]', line)
    if m:
        cur_mut = m.group(1)
    for pm in re.finditer(r'property\s*=\s*"([A-Za-z]+)".*?input\s*=\s*"([^"]*)"', line):
        rows.append((cur_mut, pm.group(1), pm.group(2)))

def tokenize(s):
    out, cur = [], ""
    for ch in s:
        if ch in "()":
            if cur: out.append(cur); cur=""
            out.append(ch)
        elif ch.isspace():
            if cur: out.append(cur); cur=""
        else:
            cur += ch
    if cur: out.append(cur)
    return out

def parse(toks):
    t = toks.pop(0)
    if t == "(":
        lst=[]
        while toks[0] != ")":
            lst.append(parse(toks))
        toks.pop(0)
        return lst
    return t

def z(tok):
    n = int(tok)
    return f"({n})" if n < 0 else f"{n}"

def tree(e):
    if e == "E": return "E"
    if isinstance(e, list) and e == ["E"]: return "E"
    # (T <color> <l> <k> <v> <r>) ; color is bare B/R (or (B)/(R))
    assert isinstance(e, list) and e[0] == "T", e
    col = e[1]
    col = col[0] if isinstance(col, list) else col
    return f"(T {col} {tree(e[2])} {z(e[3])} {z(e[4])} {tree(e[5])})"

def arg(e):
    return tree(e) if (e == "E" or isinstance(e, list)) else z(e)

out = []
for mut, prop, inp in rows:
    toks = tokenize(inp)
    parsed = parse(toks)
    elems = parsed if isinstance(parsed, list) else [parsed]
    coq_args = " ".join(arg(e) for e in elems)
    label = f"{mut}/{prop}"
    out.append(f'Compute ("{label}"%string, prop_{prop} {coq_args}).')

print(f"(* {len(out)} witnesses *)")
print("\n".join(out))
