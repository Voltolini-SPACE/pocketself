#!/usr/bin/env python3
"""PocketSelf — biblioteca do roteiro de validação no aparelho: abre o app, toca/digita pelo agente (modo manual `/acao`)
e captura as telas. Requer: PS_DEVICE=<UDID>; sessão do agente ativa (scripts/agente-iphone.sh), `ios forward 14292 14292` e o app instalado.
Uso como módulo: `import tour; tour.abrir(); tour.tocar("Continuar"); tour.foto("01-boas-vindas")`."""
import json, os, subprocess, time, urllib.request, urllib.error
DEV = os.environ["PS_DEVICE"]  # UDID do iPhone: `xcrun devicectl list devices`
BUNDLE = os.environ.get("PS_BUNDLE", "io.github.voltolini-space.pocketself")
SAIDA = os.environ.get("PS_SAIDA", "evidence/apresentacao")
TOKEN = open(os.path.expanduser("~/.config/pocketself/agente.token")).read().strip()
BASE = "http://127.0.0.1:14292"

def api(caminho, corpo=None, timeout=60):
    req = urllib.request.Request(BASE + caminho, data=None if corpo is None else json.dumps(corpo).encode(),
                                 headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}, method="GET" if corpo is None else "POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r: return json.loads(r.read())
    except urllib.error.HTTPError as e: return json.loads(e.read() or b"{}") | {"http": e.code}

def elementos(): return api("/elementos").get("texto", "")
def acao(**kw): return api("/acao", kw)
def tocar(rotulo, espera=1.2):
    r = acao(acao="tocar", rotulo=rotulo); time.sleep(espera); return r
def digitar(texto, rotulo=None, espera=0.8):
    r = acao(acao="digitar", texto=texto, **({"rotulo": rotulo} if rotulo else {})); time.sleep(espera); return r
def rolar(direcao="baixo", vezes=1):
    for _ in range(vezes): acao(acao="rolar", direcao=direcao); time.sleep(0.6)
def tocar_xy(x, y, espera=1.0):
    r = api("/acao", {"acao": "tocar", "x": x, "y": y}); time.sleep(espera); return r
def arrastar(x, y, x2, y2, espera=1.0):
    r = api("/acao", {"acao": "arrastar", "x": x, "y": y, "x2": x2, "y2": y2}); time.sleep(espera); return r
def arrastar_de(rotulo, dx, espera=1.0):
    """Arrasta na horizontal a partir do centro de um elemento (ex.: carrossel de personagens)."""
    r = api("/acao", {"acao": "arrastar", "rotulo": rotulo, "dx": dx}); time.sleep(espera); return r
def alerta(rotulo, espera=1.2):
    """Toca em um botão do alerta de permissão do sistema (ex.: «Permitir»)."""
    r = api("/acao", {"acao": "alerta", "rotulo": rotulo}); time.sleep(espera); return r
def voltar_inicio(): return acao(acao="inicio")
def abrir(*args, espera=5):
    """Reabre o PocketSelf (encerrando o anterior) com argumentos de teste do app."""
    subprocess.run(["xcrun", "devicectl", "device", "process", "launch", "--terminate-existing", "--device", DEV, BUNDLE, "--", "--acordado", *args],
                   capture_output=True); time.sleep(espera)
def foto(nome, largura=720):
    """Captura em tela cheia e guarda JPEG reduzido (o PNG original tem ~7 MB)."""
    os.makedirs(SAIDA, exist_ok=True)
    tmp = f"/tmp/ps-captura-{os.getpid()}.png"
    subprocess.run(["xcrun", "devicectl", "device", "capture", "screenshot", "--device", DEV, "--destination", tmp], capture_output=True)
    from PIL import Image
    im = Image.open(tmp).convert("RGB"); h = round(im.size[1] * largura / im.size[0])
    im.resize((largura, h), Image.LANCZOS).save(f"{SAIDA}/{nome}.jpg", quality=84, optimize=True); os.remove(tmp)
    return f"{SAIDA}/{nome}.jpg"
def mostrar(n=40):
    for l in elementos().splitlines()[:n]: print(l)
if __name__ == "__main__":
    mostrar()
