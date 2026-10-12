#!/usr/bin/env python3
"""Gera as peças de divulgação a partir das capturas REAIS do app (evidence/apresentacao):
- docs/marketing/vitrine/NN-*.png  · 1080×1920 (stories, App Store, redes 9:16)
- docs/marketing/banner-1600x900.png e social-preview-1280x640.png
- docs/marketing/demo-*.gif (sequências curtas de telas)
Uso: python3 scripts/gerar-vitrine.py   (requer Pillow; fonte Avenir Next do macOS)"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
CAP = "evidence/apresentacao"; OUT = "docs/marketing"; VIT = f"{OUT}/vitrine"
os.makedirs(VIT, exist_ok=True)
FONTE = "/System/Library/Fonts/Avenir Next.ttc"
def f(tam, peso="heavy"): return ImageFont.truetype(FONTE, tam, index={"heavy": 8, "bold": 0, "demi": 2, "medium": 5, "regular": 7}[peso])
def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
NOITE, NOITE2, PAPEL, INDIGO, CORAL, LILAS, TINTA = "15122B", "2B2551", "F8F5F0", "4F46E5", "FF7A59", "B4B0FF", "1E1A36"

# marca em pixel (mesma grade de scripts/gerar-marca.py, lida do Marca.swift gerado)
import re
src = open("app/PocketSelf/Marca.swift").read()
GRADE = re.findall(r'"([.A-Z]{20})"', src)
PAL = dict(re.findall(r'case "([A-Z])": return "([0-9A-F]{6})"', src))
def marca(tam, contorno=None):
    n = len(GRADE); esc = tam // n
    im = Image.new("RGBA", (n * esc, n * esc), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for y, l in enumerate(GRADE):
        for x, ch in enumerate(l):
            if ch in PAL:
                cor = contorno if (ch == "I" and contorno) else PAL[ch]
                d.rectangle([x * esc, y * esc, x * esc + esc - 1, y * esc + esc - 1], fill=rgb(cor))
    return im

def fundo(w, h, escuro=True):
    a, b = (rgb(NOITE), rgb(NOITE2)) if escuro else (rgb(PAPEL), rgb("EFEAF8"))
    im = Image.new("RGB", (w, h), a); d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h; d.line([(0, y), (w, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    # brilho suave
    g = Image.new("L", (w, h), 0); dg = ImageDraw.Draw(g); dg.ellipse([w * 0.35, -h * 0.15, w * 1.25, h * 0.45], fill=90)
    g = g.filter(ImageFilter.GaussianBlur(160)); cor = Image.new("RGB", (w, h), rgb(INDIGO if escuro else "C7C3FF"))
    return Image.composite(cor, im, g)

def celular(cap, largura):
    """Moldura simples de iPhone com a captura real."""
    tela = Image.open(f"{CAP}/{cap}.jpg").convert("RGB")
    h = round(tela.height * largura / tela.width); tela = tela.resize((largura, h), Image.LANCZOS)
    borda = 18; r = 70
    caixa = Image.new("RGBA", (largura + 2 * borda, h + 2 * borda), (0, 0, 0, 0))
    m = Image.new("L", caixa.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, *caixa.size], r + borda, fill=255)
    corpo = Image.new("RGBA", caixa.size, rgb("0B0A14") + (255,)); caixa.paste(corpo, (0, 0), m)
    mt = Image.new("L", tela.size, 0); ImageDraw.Draw(mt).rounded_rectangle([0, 0, *tela.size], r, fill=255)
    caixa.paste(tela, (borda, borda), mt)
    sombra = Image.new("RGBA", (caixa.width + 120, caixa.height + 120), (0, 0, 0, 0))
    ms = Image.new("L", sombra.size, 0); ImageDraw.Draw(ms).rounded_rectangle([60, 80, 60 + caixa.width, 80 + caixa.height], r, fill=150)
    sombra.putalpha(ms.filter(ImageFilter.GaussianBlur(40))); sombra.paste(caixa, (60, 60), caixa)
    return sombra

def texto_quebrado(d, xy, txt, fonte, cor, destaque=None, cor_dest=None, entre=1.08):
    x, y = xy
    for linha in txt.split("\n"):
        cx = x
        for palavra in linha.split(" "):
            c = cor_dest if destaque and palavra.strip(".,?!") in [w.strip(".,?!") for w in destaque] else cor
            d.text((cx, y), palavra, font=fonte, fill=rgb(c)); cx += d.textlength(palavra + " ", font=fonte)
        y += int(fonte.size * entre)
    return y

def chips(d, x, y, itens, escuro=True):
    fo = f(30, "demi")
    for t in itens:
        w = d.textlength(t, font=fo) + 44
        d.rounded_rectangle([x, y, x + w, y + 58], 29, fill=rgb("2E2858" if escuro else "FFFFFF"), outline=rgb(LILAS if escuro else "DDD7E8"), width=2)
        d.text((x + 22, y + 10), t, font=fo, fill=rgb("F2EFFB" if escuro else TINTA)); x += w + 14

PECAS = [
    ("00-ligue-para-sua-ia", "45-ao-vivo-chamada", "Ligue para a\nsua IA. Sem sinal.", ["sinal."], "Fale e ouça a resposta em voz, como numa ligação.\nReconhecimento, IA e voz rodam no iPhone.", ["Modo avião", "Você interrompe", "Áudio não sai do iPhone"], True),
    ("01-sua-ia-no-bolso", "10-chat-inicio-claro", "Sua IA.\nNo seu bolso.", ["bolso."], "Um agente pessoal que roda inteiro no iPhone.\nSem conta. Sem assinatura. Código aberto.", ["100% no aparelho", "Sem conta", "MIT"], True),
    ("02-sem-sinal", "42-chat-sos-lanterna", "Sem sinal?\nSem problema.", ["problema."], "SOS pela lanterna, GPS e conversa com a IA:\ntudo funciona sem internet.", ["Offline", "SOS em Morse", "GPS"], True),
    ("03-do-seu-jeito", "06-montador-coruja-cachecol-planta", "Do seu jeito.\nDe verdade.", ["verdade."], "Dê um nome, escolha como ele te chama e monte\no mascote: 14 personagens, 14 acessórios, 8 objetos.", ["Nome", "Mascote", "Voz"], False),
    ("04-acao-com-seu-toque", "37-chat-lembrete", "A IA prepara.\nVocê decide.", ["decide."], "Lembretes, agenda e mensagens ficam prontos —\ne só acontecem quando você toca em Confirmar.", ["Confirmação", "Sem surpresas"], False),
    ("05-escolha-o-cerebro", "18-ajustes-motor", "Você escolhe\no cérebro.", ["cérebro."], "Qwen, Gemma, Apple Intelligence ou o seu servidor.\nMedido no seu aparelho: até 47 tokens/s.", ["4 modelos locais", "Apple Intelligence"], True),
    ("06-suas-palavras", "38-chat-mensagem-confirmacao", "Suas palavras.\nExatamente.", ["Exatamente."], "A mensagem vai como você escreveu.\nO app impede a IA de trocar o que você disse.", ["Fidelidade", "Você envia"], False),
    ("07-memoria", "36-chat-memoria", "Memória que\nvocê controla.", ["controla."], "O PocketSelf propõe, você aprova.\nEdite, pause ou apague quando quiser.", ["Aprovação", "Apague quando quiser"], True),
    ("08-cria-imagens", "35-chat-criar-imagem", "Imagina.\nE cria.", ["cria."], "Com o Apple Intelligence ligado, uma ilustração\nem segundos, no próprio iPhone.", ["Image Playground", "No aparelho"], False),
    ("09-claro-e-escuro", "12-chat-inicio-escuro", "Bonito de dia.\nE de noite.", ["noite."], "Temas claro e escuro, quatro cores de destaque\ne contraste conferido para leitura confortável.", ["WCAG", "Dynamic Type"], True),
]

def peca(nome, cap, titulo, dest, sub, ch, escuro):
    W, H = 1080, 1920
    im = fundo(W, H, escuro); d = ImageDraw.Draw(im)
    m = marca(80, "A79CE0" if escuro else None); im.paste(m, (80, 86), m)
    d.text((182, 92), "Pocket", font=f(46), fill=rgb("F2EFFB" if escuro else TINTA))
    d.text((182 + d.textlength("Pocket", font=f(46)), 92), "Self", font=f(46), fill=rgb(LILAS if escuro else INDIGO))
    y = texto_quebrado(d, (80, 220), titulo, f(104), "F2EFFB" if escuro else TINTA, dest, CORAL if escuro else INDIGO, 1.05)
    y = texto_quebrado(d, (82, y + 18), sub, f(36, "medium"), "C9C3E3" if escuro else "5A5473", entre=1.35)
    chips(d, 80, y + 22, ch, escuro)
    tel = celular(cap, 600); im.paste(tel, ((W - tel.width) // 2, max(y + 110, H - tel.height + 330)), tel)
    im.save(f"{VIT}/{nome}.png", optimize=True)

for p in PECAS: peca(*p)

# fecho
W, H = 1080, 1920; im = fundo(W, H, True); d = ImageDraw.Draw(im)
m = marca(400, "A79CE0"); im.paste(m, ((W - m.width) // 2, 420), m)
fo = f(110); tw = d.textlength("PocketSelf", font=fo); d.text(((W - tw) / 2, 900), "Pocket", font=fo, fill=rgb("F2EFFB")); d.text(((W - tw) / 2 + d.textlength("Pocket", font=fo), 900), "Self", font=fo, fill=rgb(LILAS))
for i, (t, fo2, cor) in enumerate([("Your AI. Your Pocket. Your Rules.", f(48, "demi"), "F2EFFB"), ("Sua IA. Seu bolso. Suas regras.", f(40, "medium"), "C9C3E3"), ("Grátis · Código aberto (MIT) · iPhone", f(36, "medium"), LILAS)]):
    tw2 = d.textlength(t, font=fo2); d.text(((W - tw2) / 2, 1060 + i * 80), t, font=fo2, fill=rgb(cor))
im.save(f"{VIT}/10-pocketself.png", optimize=True)

# banner 16:9 e prévia social
def banner(W, H, nome, caps):
    im = fundo(W, H, True); d = ImageDraw.Draw(im)
    m = marca(int(H * 0.16), "A79CE0"); im.paste(m, (int(W * 0.06), int(H * 0.12)), m)
    fo = f(int(H * 0.12)); x = int(W * 0.06); y = int(H * 0.34)
    d.text((x, y), "Pocket", font=fo, fill=rgb("F2EFFB")); d.text((x + d.textlength("Pocket", font=fo), y), "Self", font=fo, fill=rgb(LILAS))
    d.text((x, y + int(H * 0.15)), "Sua IA. Seu bolso. Suas regras.", font=f(int(H * 0.055), "demi"), fill=rgb("F2EFFB"))
    d.text((x, y + int(H * 0.23)), "Agente pessoal que roda no iPhone, até sem internet.", font=f(int(H * 0.04), "medium"), fill=rgb("C9C3E3"))
    lar = int(H * 0.36)
    for i, c in enumerate(caps):
        t = celular(c, lar); im.paste(t, (int(W * 0.58) + i * int(lar * 0.62), int(H * 0.10) + (i % 2) * int(H * 0.08)), t)
    im.save(f"{OUT}/{nome}", optimize=True)
banner(1600, 900, "banner-1600x900.png", ["10-chat-inicio-claro", "42-chat-sos-lanterna", "06-montador-coruja-cachecol-planta"])
banner(1280, 640, "social-preview-1280x640.png", ["10-chat-inicio-claro", "42-chat-sos-lanterna", "06-montador-coruja-cachecol-planta"])

# GIFs de demonstração (telas reais em sequência)
def gif(nome, caps, larg=360, ms=1300):
    quadros = [Image.open(f"{CAP}/{c}.jpg").convert("RGB").resize((larg, round(larg * 1564 / 720)), Image.LANCZOS) for c in caps]
    quadros[0].save(f"{OUT}/{nome}", save_all=True, append_images=quadros[1:], duration=ms, loop=0, optimize=True)
gif("demo-primeiro-uso.gif", ["01-onboarding-boas-vindas", "02-onboarding-nome", "03-onboarding-montador-inicial", "04-montador-raposa-bruxo-livro", "06-montador-coruja-cachecol-planta", "07-montador-pinguim-gravata-balao", "09-onboarding-pronto", "10-chat-inicio-claro"])
gif("demo-acoes.gif", ["30-chat-hora-data", "32-chat-lanterna-ligar", "37-chat-lembrete", "38-chat-mensagem-confirmacao", "36-chat-memoria", "35-chat-criar-imagem", "42-chat-sos-lanterna"], ms=1800)
print("ok:", sorted(os.listdir(VIT)))
