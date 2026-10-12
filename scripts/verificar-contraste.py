#!/usr/bin/env python3
"""Confere o contraste (WCAG) das cores do tema lendo app/PocketSelf/Tema.swift. Sai com 1 se algum par falhar."""
import re, sys, pathlib
src = (pathlib.Path(__file__).parent.parent / "app/PocketSelf/Tema.swift").read_text()
def lum(h):
    c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def cr(a, b):
    la, lb = lum(a), lum(b)
    if la < lb: la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)
tok = {m.group(1): (m.group(2), m.group(3)) for m in re.finditer(r'static let (\w+) = Color\.dinamica\("([0-9A-F]{6})", "([0-9A-F]{6})"\)', src)}
dest = {}
for caso in re.finditer(r'var (claro|escuroFundo|escuroTinta): String \{\s*switch self \{(.*?)\}\s*\}', src, re.S):
    for m in re.finditer(r'case \.(\w+): return "([0-9A-F]{6})"', caso.group(2)): dest.setdefault(m.group(1), {})[caso.group(1)] = m.group(2)
falhas = 0
def exige(nome, valor, minimo):
    global falhas
    ok = valor >= minimo; falhas += (not ok)
    print(("ok    " if ok else "FALHA ") + f"{nome}: {valor:.2f} (mín. {minimo})")
for i, tema in enumerate(("claro", "escuro")):
    f, s = tok["fundo"][i], tok["superficie"][i]
    exige(f"{tema} texto/fundo", cr(tok["texto"][i], f), 4.5)
    exige(f"{tema} secundário/fundo", cr(tok["secundario"][i], f), 4.5)
    exige(f"{tema} secundário/superfície", cr(tok["secundario"][i], s), 4.5)
    exige(f"{tema} borda/fundo", cr(tok["borda"][i], f), 3)
    exige(f"{tema} borda/superfície", cr(tok["borda"][i], s), 3)
for nome, d in dest.items():
    exige(f"{nome} claro: branco sobre botão", cr("FFFFFF", d["claro"]), 4.5)
    exige(f"{nome} claro: tinta/fundo", cr(d["claro"], tok["fundo"][0]), 4.5)
    exige(f"{nome} escuro: branco sobre botão", cr("FFFFFF", d["escuroFundo"]), 4.5)
    exige(f"{nome} escuro: botão/superfície", cr(d["escuroFundo"], tok["superficie"][1]), 3)
    exige(f"{nome} escuro: tinta/superfície", cr(d["escuroTinta"], tok["superficie"][1]), 4.5)
m = re.search(r'perigoTexto = Color\.dinamica\("([0-9A-F]{6})", "([0-9A-F]{6})"\)', src)
exige("erro claro: texto/superfície", cr(m.group(1), tok["superficie"][0]), 4.5)
exige("erro escuro: texto/superfície", cr(m.group(2), tok["superficie"][1]), 4.5)
exige("erro escuro: texto/suave", cr(m.group(2), tok["suave"][1]), 4.5)
exige("perigo: branco sobre botão", cr("FFFFFF", re.search(r'perigo = Color\(hex: "([0-9A-F]{6})"', src).group(1)), 4.5)
print("OK: contraste conferido." if not falhas else f"{falhas} par(es) abaixo do mínimo."); sys.exit(1 if falhas else 0)
