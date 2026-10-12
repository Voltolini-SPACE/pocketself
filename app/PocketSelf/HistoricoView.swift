// PocketSelf — aba Histórico: lista de conversas, busca local, fixadas como filtro (não como aba).
import SwiftUI

struct HistoricoView: View {
    @Environment(Historico.self) private var historico
    @Environment(Motor.self) private var motor
    @Environment(Preferencias.self) private var prefs
    @Environment(Rota.self) private var rota

    @State private var busca = ""
    @State private var soFixadas = false
    @State private var renomeando: Conversa?
    @State private var novoTitulo = ""
    @State private var excluindo: Conversa?

    private var tinta: Color { Tema.tinta(prefs.destaque) }

    private var filtradas: [Conversa] {
        historico.ordenadas.filter { c in
            (!soFixadas || c.fixada) && (busca.isEmpty || c.tituloExibido.localizedCaseInsensitiveContains(busca)
                || c.mensagens.contains { $0.texto.localizedCaseInsensitiveContains(busca) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Cabecalho()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Suas conversas").font(Tema.titulo).foregroundStyle(Tema.texto).padding(.bottom, 12)
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Tema.secundario)
                        TextField("Buscar uma conversa", text: $busca).font(.callout).foregroundStyle(Tema.texto)
                    }
                    .padding(.horizontal, 12).frame(minHeight: 40)
                    .background(Tema.superficie, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tema.borda, lineWidth: 1))
                    HStack(spacing: 7) {
                        filtro("Todas", ativo: !soFixadas) { soFixadas = false }
                        filtro("Fixadas", ativo: soFixadas) { soFixadas = true }
                    }
                    .padding(.vertical, 10)
                    if filtradas.isEmpty {
                        Text(historico.conversas.isEmpty ? "Suas conversas vão aparecer aqui." : "Não encontrei uma conversa com esse termo.")
                            .font(.callout).foregroundStyle(Tema.secundario).frame(maxWidth: .infinity).padding(.vertical, 38)
                    } else {
                        ForEach(grupos, id: \.0) { nome, itens in
                            RotuloDeGrupo(texto: "\(nome) · \(itens.count)")
                            ForEach(itens) { c in linha(c) }
                        }
                    }
                }
                .padding(Tema.margem)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Tema.fundo)
        .alert("Renomear conversa", isPresented: Binding(get: { renomeando != nil }, set: { if !$0 { renomeando = nil } })) {
            TextField("Título", text: $novoTitulo)
            Button("Salvar") { if let c = renomeando { historico.renomear(c.id, para: novoTitulo) }; renomeando = nil }
            Button("Cancelar", role: .cancel) { renomeando = nil }
        }
        .confirmationDialog("Excluir esta conversa?", isPresented: Binding(get: { excluindo != nil }, set: { if !$0 { excluindo = nil } }), titleVisibility: .visible) {
            Button("Excluir conversa e mensagens", role: .destructive) {
                if let c = excluindo { motor.esquecer(conversa: c.id); historico.excluir(c.id) }
                excluindo = nil
            }
            Button("Cancelar", role: .cancel) { excluindo = nil }
        } message: {
            Text("Remove a conversa e as mensagens deste iPhone. Não há cópia em outro lugar.")
        }
    }

    private var grupos: [(String, [Conversa])] {
        let cal = Calendar.current
        var hoje: [Conversa] = [], ontem: [Conversa] = [], semana: [Conversa] = [], antes: [Conversa] = []
        for c in filtradas {
            if cal.isDateInToday(c.atualizadaEm) { hoje.append(c) }
            else if cal.isDateInYesterday(c.atualizadaEm) { ontem.append(c) }
            else if let d = cal.date(byAdding: .day, value: -7, to: Date()), c.atualizadaEm > d { semana.append(c) }
            else { antes.append(c) }
        }
        return [("Hoje", hoje), ("Ontem", ontem), ("Esta semana", semana), ("Antes", antes)].filter { !$0.1.isEmpty }
    }

    private func filtro(_ titulo: String, ativo: Bool, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(titulo).font(.footnote.weight(.medium))
                .foregroundStyle(ativo ? .white : Tema.texto)
                .padding(.horizontal, 12).frame(minHeight: 34)
                .background(ativo ? Tema.acao(prefs.destaque) : Tema.superficie, in: Capsule())
                .overlay(Capsule().stroke(ativo ? Color.clear : Tema.borda, lineWidth: 1))
                .frame(minHeight: 44)
        }
    }

    private static let hora: DateFormatter = { let f = DateFormatter(); f.timeStyle = .short; return f }()

    private func linha(_ c: Conversa) -> some View {
        Button {
            historico.abrir(c.id)
            rota.aba = .chat
        } label: {
            HStack(spacing: 12) {
                Image(systemName: c.fixada ? "pin" : (c.teveVoz ? "waveform" : "bubble.left"))
                    .foregroundStyle(tinta).frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(c.tituloExibido).font(.footnote.weight(.semibold)).foregroundStyle(Tema.texto).lineLimit(1)
                    Text(c.resumo).font(.caption).foregroundStyle(Tema.secundario).lineLimit(1)
                    Text(Self.hora.string(from: c.atualizadaEm) + (c.fixada ? " · Fixada" : "")).font(.caption2).foregroundStyle(Tema.secundario)
                }
                Spacer()
                Menu {
                    Button(c.fixada ? "Desafixar" : "Fixar", systemImage: "pin") { historico.fixar(c.id) }
                    Button("Renomear", systemImage: "pencil") { novoTitulo = c.titulo; renomeando = c }
                    Button("Excluir", systemImage: "trash", role: .destructive) { excluindo = c }
                } label: {
                    Image(systemName: "ellipsis").foregroundStyle(Tema.secundario).frame(width: 44, height: 44)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 6)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.raio))
            .overlay(RoundedRectangle(cornerRadius: Tema.raio).stroke(Tema.separador, lineWidth: 1))
        }
        .padding(.bottom, 6)
    }
}
