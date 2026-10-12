// PocketSelf — aba Agenda (aprovada pelo dono em 10/10): compromissos e lembretes, lidos do iPhone (EventKit).
// Só leitura aqui; criar continua pelo chat, com confirmação.
import EventKit
import SwiftUI

@Observable
@MainActor
final class Agenda {
    struct Item: Identifiable { let id: String; let titulo: String; let quando: Date?; let diaInteiro: Bool; let local: String?; let lembrete: Bool; let cor: CGColor? }
    var eventos: [Item] = []
    var lembretes: [Item] = []
    var semAcessoAgenda = false
    var semAcessoLembretes = false
    var carregando = false
    @ObservationIgnored private let loja = EKEventStore()

    func atualizar(dias: Int = 7) async {
        carregando = true
        defer { carregando = false }
        let okE = EKEventStore.authorizationStatus(for: .event) == .fullAccess ? true : ((try? await loja.requestFullAccessToEvents()) ?? false)
        semAcessoAgenda = !okE
        if okE {
            let ini = Calendar.current.startOfDay(for: Date())
            let fim = Calendar.current.date(byAdding: .day, value: dias, to: ini)!
            eventos = loja.events(matching: loja.predicateForEvents(withStart: ini, end: fim, calendars: nil))
                .sorted { $0.startDate < $1.startDate }
                .map { Item(id: $0.eventIdentifier ?? UUID().uuidString, titulo: $0.title ?? "(sem título)", quando: $0.startDate, diaInteiro: $0.isAllDay, local: $0.location, lembrete: false, cor: $0.calendar.cgColor) }
        }
        let okL = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess ? true : ((try? await loja.requestFullAccessToReminders()) ?? false)
        semAcessoLembretes = !okL
        if okL {
            let pred = loja.predicateForIncompleteReminders(withDueDateStarting: nil, ending: Calendar.current.date(byAdding: .day, value: dias, to: Date()), calendars: nil)
            let rs: [EKReminder] = await withCheckedContinuation { c in loja.fetchReminders(matching: pred) { c.resume(returning: $0 ?? []) } }
            lembretes = rs.map { r in
                Item(id: r.calendarItemIdentifier, titulo: r.title ?? "(sem título)", quando: r.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                     diaInteiro: false, local: nil, lembrete: true, cor: r.calendar.cgColor)
            }.sorted { ($0.quando ?? .distantFuture) < ($1.quando ?? .distantFuture) }
        }
    }
}

struct AgendaView: View {
    @Environment(Preferencias.self) private var prefs
    @Environment(Rota.self) private var rota
    @State private var agenda = Agenda()

    private static let dia: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "pt_BR"); f.dateFormat = "EEEE, d 'de' MMMM"; return f }()
    private static let hora: DateFormatter = { let f = DateFormatter(); f.timeStyle = .short; return f }()

    private var porDia: [(Date, [Agenda.Item])] {
        let g = Dictionary(grouping: agenda.eventos) { Calendar.current.startOfDay(for: $0.quando ?? Date()) }
        return g.keys.sorted().map { ($0, g[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Cabecalho()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Sua agenda").font(Tema.titulo).foregroundStyle(Tema.texto)
                        Spacer()
                        if agenda.carregando { ProgressView() }
                    }
                    Text("Próximos 7 dias, direto do Calendário e dos Lembretes do iPhone.").font(.footnote).foregroundStyle(Tema.secundario).padding(.top, 4)
                    Button { rota.aba = .chat } label: { Label("Marcar pelo chat", systemImage: "plus") }
                        .buttonStyle(BotaoSecundario(altura: 40)).padding(.top, 12)

                    if agenda.semAcessoAgenda { Aviso(texto: "Sem acesso ao Calendário. Libere em Ajustes do iPhone › Privacidade › Calendários.", cor: Tema.perigoTexto).padding(.top, 12) }
                    RotuloDeGrupo(texto: "Compromissos · \(agenda.eventos.count)")
                    if agenda.eventos.isEmpty && !agenda.semAcessoAgenda { vazio("Nenhum compromisso nos próximos 7 dias.") }
                    ForEach(porDia, id: \.0) { dia, itens in
                        Text((Calendar.current.isDateInToday(dia) ? "Hoje · " : Calendar.current.isDateInTomorrow(dia) ? "Amanhã · " : "") + Self.dia.string(from: dia))
                            .font(.caption.weight(.semibold)).foregroundStyle(Tema.secundario).padding(.top, 8).padding(.bottom, 6)
                        ForEach(itens) { linha($0) }
                    }

                    if agenda.semAcessoLembretes { Aviso(texto: "Sem acesso aos Lembretes. Libere em Ajustes do iPhone › Privacidade › Lembretes.", cor: Tema.perigoTexto).padding(.top, 12) }
                    RotuloDeGrupo(texto: "Lembretes pendentes · \(agenda.lembretes.count)")
                    if agenda.lembretes.isEmpty && !agenda.semAcessoLembretes { vazio("Nenhum lembrete pendente.") }
                    ForEach(agenda.lembretes) { linha($0) }
                }
                .padding(Tema.margem)
            }
            .refreshable { await agenda.atualizar() }
        }
        .background(Tema.fundo)
        .task { await agenda.atualizar() }
    }

    private func vazio(_ t: String) -> some View {
        Text(t).font(.footnote).foregroundStyle(Tema.secundario).padding(.vertical, 8)
    }

    private func linha(_ i: Agenda.Item) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(i.cor.map { Color(cgColor: $0) } ?? Tema.acao(prefs.destaque)).frame(width: 4, height: 34)
            Image(systemName: i.lembrete ? "checklist" : "calendar").foregroundStyle(Tema.secundario).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(i.titulo).font(.footnote.weight(.semibold)).foregroundStyle(Tema.texto).lineLimit(2)
                Text(rotulo(i)).font(.caption2).foregroundStyle(Tema.secundario)
            }
            Spacer()
        }
        .padding(10)
        .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.raio))
        .overlay(RoundedRectangle(cornerRadius: Tema.raio).stroke(Tema.separador, lineWidth: 1))
        .padding(.bottom, 6)
    }

    private func rotulo(_ i: Agenda.Item) -> String {
        var partes: [String] = []
        if i.diaInteiro { partes.append("dia inteiro") }
        else if let q = i.quando { partes.append(i.lembrete ? (Self.dia.string(from: q) + ", " + Self.hora.string(from: q)) : Self.hora.string(from: q)) }
        else { partes.append("sem horário") }
        if let l = i.local, !l.isEmpty { partes.append(l) }
        return partes.joined(separator: " · ")
    }
}
