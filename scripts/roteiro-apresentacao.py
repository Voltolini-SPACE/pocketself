#!/usr/bin/env python3
"""Roteiro automatizado no aparelho + capturas para a apresentação. Etapas: onboarding | telas | ferramentas.
Uso: python3 scripts/roteiro-apresentacao.py onboarding   (ver scripts/tour.py para os pré-requisitos)"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
import tour

def espera_tela(trecho, tentativas=8):
    for _ in range(tentativas):
        if trecho in tour.elementos(): return True
        time.sleep(1)
    print("!! tela esperada não apareceu:", trecho); return False

def onboarding():
    tour.abrir("--perfil=novo", "--tema=claro")
    espera_tela("BEM-VINDO"); tour.foto("01-onboarding-boas-vindas")
    tour.tocar("Continuar"); espera_tela("PASSO 1 DE 3")
    tour.acao(acao="digitar", n=5, texto="\b" * 14 + "Luma"); tour.acao(acao="digitar", n=7, texto="Ana")
    tour.foto("02-onboarding-nome")
    tour.tocar("Continuar"); espera_tela("PASSO 2 DE 3")
    tour.foto("03-onboarding-montador-inicial")
    # variações de personagem (argumento --mascote): relança o app já no passo do montador
    variacoes = [("04-montador-raposa-bruxo-livro", "raposa,3,bruxo,esperto,livro"), ("05-montador-robo-oculos-cafe", "robo,4,oculos,surpreso,cafe"),
                 ("06-montador-coruja-cachecol-planta", "coruja,1,cachecol,feliz,planta"), ("07-montador-pinguim-gravata-balao", "pinguim,4,borboleta,feliz,balao"),
                 ("08-montador-polvo-coroa-coracao", "polvo,0,coroa,calmo,coracao")]
    for nome, m in variacoes:
        tour.abrir("--perfil=novo", "--tema=claro", f"--mascote={m}")
        espera_tela("BEM-VINDO"); tour.tocar("Continuar"); espera_tela("PASSO 1 DE 3")
        tour.acao(acao="digitar", n=5, texto="\b" * 14 + "Luma"); tour.acao(acao="digitar", n=7, texto="Ana")
        tour.tocar("Continuar"); espera_tela("PASSO 2 DE 3"); tour.foto(nome)
    tour.tocar("Continuar"); espera_tela("PASSO 3 DE 3"); tour.foto("09-onboarding-pronto")
    tour.mostrar(20)

ARGS_APP = ["-agenteConcluido", "YES", "-agenteNome", "Luma", "-agenteTratamento", "Ana", "--mascote=coruja,1,bruxo,feliz,livro"]

def telas(apenas_ajustes=False):
    if not apenas_ajustes:
        tour.abrir("--tema=claro", *ARGS_APP); espera_tela("OLÁ, ANA"); tour.foto("10-chat-inicio-claro")
    tour.rolar("baixo", 1); tour.foto("11-chat-acoes-rapidas")
    tour.abrir("--tema=escuro", *ARGS_APP); espera_tela("OLÁ, ANA"); tour.foto("12-chat-inicio-escuro")
    tour.abrir("--tema=claro", *ARGS_APP); espera_tela("OLÁ, ANA")
    tour.tocar("Ajustes"); espera_tela("Do seu jeito"); tour.foto("13-ajustes")
    sub = [("Meu agente", "14-ajustes-meu-agente"), ("Controle do iPhone", "15-ajustes-controle"), ("Aparência", "16-ajustes-aparencia"),
           ("Voz e áudio", "17-ajustes-voz"), ("Motor de IA", "18-ajustes-motor"), ("PocketSelf Decide", "19-ajustes-decide"),
           ("Integrações", "20-ajustes-integracoes"), ("Memória", "21-ajustes-memoria"), ("Privacidade e dados", "22-ajustes-privacidade"),
           ("Sobre o PocketSelf", "23-ajustes-sobre")]
    for rotulo, nome in sub:
        tour.tocar(rotulo, 1.5); tour.foto(nome)
        if rotulo in ("Motor de IA", "Aparência", "Voz e áudio", "Integrações", "Privacidade e dados"):
            tour.rolar("baixo", 1); tour.foto(nome + "-b")
        tour.tocar("Back", 1.2)
        espera_tela("Do seu jeito", 4)

def cena(nome, pergunta, espera=28, motor="qwen3.5-4b", depois=None, tema="claro", permissoes=False):
    """Abre o app com uma pergunta automática, espera a resposta, trata permissões e captura."""
    tour.abrir(f"--tema={tema}", *ARGS_APP, f"--motor={motor}", f"--pergunta={pergunta}", espera=4)
    for _ in range(int(espera // 4)):
        time.sleep(4)
        if permissoes:
            for r in ("Permitir acesso total", "Durante o Uso", "Permitir"):
                if "erro" not in tour.alerta(r, 1.0): break
    if depois: depois()
    tour.foto(nome)
    with open(os.path.join(tour.SAIDA, "log-cenas.txt"), "a") as f:
        f.write(f"## {nome}: {pergunta}\n" + tour.elementos()[:1800] + "\n\n")

def ferramentas():
    cena("30-chat-hora-data", "Que horas são e que dia é hoje?", 24)
    cena("31-chat-bateria", "Qual é o nível da bateria do meu iPhone e quanto espaço livre eu tenho?", 24)
    cena("32-chat-lanterna-ligar", "Ligue a lanterna.", 24)
    cena("33-chat-lanterna-desligar", "Desligue a lanterna.", 24)
    cena("34-chat-web-sem-internet", "Pesquise na internet o preço do dólar hoje.", 32)
    cena("35-chat-criar-imagem", "Crie uma imagem de uma ilha deserta ao pôr do sol.", 48)
    cena("36-chat-memoria", "Lembre que eu prefiro respostas curtas e diretas.", 28)
    cena("37-chat-lembrete", "Me lembre amanhã às 9h de revisar o PocketSelf (teste).", 36, permissoes=True)
    cena("38-chat-mensagem-confirmacao", "Mande uma mensagem para o número 555-0100 dizendo: chego em 10 minutos.", 36)
    cena("39-chat-apple-intelligence", "Explique em duas frases o que são juros compostos.", 24, motor="apple")
    cena("40-chat-apple-pedido-de-acao", "Me lembre amanhã às 9h de ligar para o contador.", 24, motor="apple")

def resgate():
    cena("41-chat-localizacao-gps", "Qual é a minha localização? Preciso das coordenadas.", 60, permissoes=True)
    cena("42-chat-sos-lanterna", "Faça sinal de SOS com a lanterna.", 30)
    cena("43-chat-bateria-brilho", "Estou com pouca bateria. Reduza o brilho da tela para 10%.", 30)
    cena("44-chat-timer", "Crie um timer de 30 minutos chamado fogueira.", 30)

def refazer():
    cena("35-chat-criar-imagem", "Crie uma imagem de uma ilha deserta ao pôr do sol.", 48)
    cena("37-chat-lembrete", "Me lembre amanhã às 9h de revisar o PocketSelf (teste).", 36, permissoes=True)
    cena("38-chat-mensagem-confirmacao", "Mande uma mensagem para o número 555-0100 dizendo: chego em 10 minutos.", 36)
    tour.abrir("--tema=claro", *ARGS_APP); espera_tela("OLÁ, ANA")
    tour.tocar("Ajustes"); espera_tela("Do seu jeito"); tour.tocar("Privacidade e dados", 1.5); tour.foto("22-ajustes-privacidade")
    tour.rolar("baixo", 1); tour.foto("22-ajustes-privacidade-b"); tour.tocar("Back", 1.2)

if __name__ == "__main__":
    for etapa in sys.argv[1:] or ["onboarding"]: globals()[etapa]()
