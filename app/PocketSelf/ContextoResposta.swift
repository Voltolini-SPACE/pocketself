// PocketSelf — o histórico recebido já contém o pedido atual anexado pela interface.
import Foundation

enum ContextoResposta {
    static func anteriores(_ mensagens: [Spark.Msg]) -> [Spark.Msg] {
        guard mensagens.last?.role == "user" else { return mensagens }
        return Array(mensagens.dropLast())
    }

    static func historico(instrucoes: String, mensagens: [Spark.Msg], pedido: String) -> [Spark.Msg] {
        [Spark.Msg(role: "system", content: instrucoes)] + anteriores(mensagens) + [Spark.Msg(role: "user", content: pedido)]
    }

    static func instrucoes(base: String, voz: String, porVoz: Bool, memoria: String) -> String {
        (porVoz ? voz : base) + memoria + hoje()
    }

    /// Só o dia (o prefixo muda uma vez por dia, preservando o cache). Hora exata: ferramenta `hora_e_data`.
    static func hoje(_ agora: Date = Date()) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "pt_BR"); f.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy"
        return "\n\nHoje é \(f.string(from: agora)). Para a hora exata, ou antes de calcular datas relativas, chame a ferramenta hora_e_data; nunca invente hora nem data."
    }
}
