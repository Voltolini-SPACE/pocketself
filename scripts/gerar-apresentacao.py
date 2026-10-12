#!/usr/bin/env python3
"""Gera docs/apresentacao/index.html (slides, uma seção por «## ») a partir de docs/APRESENTACAO.md."""
import re, html, os
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
md = open("docs/APRESENTACAO.md").read()
secs = re.split(r"\n(?=## )", md)
out = ['<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>PocketSelf — apresentação</title><style>',
       ':root{--bg:#F8F5F0;--fg:#1E1A36;--ac:#4F46E5}@media(prefers-color-scheme:dark){:root{--bg:#15122B;--fg:#F2EFFB;--ac:#B4B0FF}}',
       'html{scroll-snap-type:y proximity}body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.5 -apple-system,system-ui,Segoe UI,sans-serif}',
       'section{min-height:100vh;scroll-snap-align:start;padding:6vh 7vw;box-sizing:border-box;display:flex;flex-direction:column;justify-content:center;gap:14px}',
       'h1,h2{margin:0;font-weight:800}h2{color:var(--ac);font-size:2rem}.grid{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start}.grid figure{margin:0;flex:1 1 200px;max-width:260px}',
       'img{max-width:100%;height:auto;border-radius:18px;box-shadow:0 8px 28px #0003}p{max-width:70ch}a{color:var(--ac)}</style></head><body>',
       '<section><img src="../marca/pocketself-logo-claro.svg" alt="PocketSelf" style="box-shadow:none;max-width:420px"><h1>Your AI. Your Pocket. Your Rules.</h1><p>Apresentação completa · capturas reais de um iPhone 17 Pro Max · 12/10/2026</p></section>']
def lk(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m: f'<a href="../{m.group(2)}">{m.group(1)}</a>', s)
    return re.sub(r"\*\*([^*]+)\*\*", lambda m: f"<b>{m.group(1)}</b>", s)
for sec in secs[1:]:
    linhas = sec.splitlines(); titulo = linhas[0][3:]; corpo = "\n".join(linhas[1:])
    imgs = re.findall(r"!\[[^\]]*\]\(([^)]+\.(?:jpg|png))\)", corpo)
    txt = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", corpo); txt = re.sub(r"^\|.*\|$", "", txt, flags=re.M)
    par = [p.strip() for p in txt.split("\n\n") if p.strip() and not p.strip().startswith(">")]
    ps = "".join("<p>" + lk(p) + "</p>" for p in par[:3])
    g = "".join(f'<figure><img loading="lazy" src="../{i}"></figure>' for i in imgs)
    out.append(f"<section><h2>{html.escape(titulo)}</h2>{ps}<div class=\"grid\">{g}</div></section>")
out.append("</body></html>")
open("docs/apresentacao/index.html", "w").write("\n".join(out))
print("slides:", len(secs), "· imagens:", sum(o.count("<img") for o in out))
