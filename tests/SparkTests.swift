import Foundation

final class SparkHTTPMock: URLProtocol {
    static var responder: (URLRequest) -> (Int, String) = { _ in (500, "missing fixture") }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body) = Self.responder(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/event-stream"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct SparkTestFailure: Error, CustomStringConvertible { let description: String }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw SparkTestFailure(description: message) }
}
func requireError(_ operation: () async throws -> Void) async throws {
    do { try await operation() } catch { return }
    throw SparkTestFailure(description: "expected explicit failure, got success")
}
let tools: [[String: Any]] = [["type": "function", "function": ["name": "allowed", "parameters": ["type": "object"]]]]
func json(_ value: Any) -> String { String(data: try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), encoding: .utf8)! }
func event(_ delta: [String: Any] = [:], finish: String? = nil) -> String {
    var choice: [String: Any] = ["index": 0, "delta": delta]
    if let finish { choice["finish_reason"] = finish }
    return "data: \(json(["choices": [choice]]))\n\n"
}
func tool(_ id: Any = "call_1", _ name: Any = "allowed", _ args: Any = "{}") -> [String: Any] {
    ["id": id, "type": "function", "function": ["name": name, "arguments": args]]
}
func requestBody(_ request: URLRequest) -> [String: Any] {
    var data = request.httpBody ?? Data()
    if data.isEmpty, let stream = request.httpBodyStream {
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
    }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}
func completion(_ request: URLRequest, calls: [[String: Any]]? = nil, text: String = "final") -> String {
    let body = requestBody(request)
    if body["stream"] as? Bool == true {
        if let calls { return event(["tool_calls": calls.enumerated().map { index, call in var c = call; c["index"] = index; return c }], finish: "tool_calls") + "data: [DONE]\n\n" }
        return event(["content": text], finish: "stop") + "data: [DONE]\n\n"
    }
    var message: [String: Any] = ["role": "assistant", "content": text]
    if let calls { message["tool_calls"] = calls }
    return json(["choices": [["message": message, "finish_reason": calls == nil ? "stop" : "tool_calls"]]])
}

@main struct SparkTests {
    static func main() async {
        URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        _ = URLProtocol.registerClass(SparkHTTPMock.self)
        var failures = 0
        func test(_ name: String, _ operation: () async throws -> Void) async {
            do { try await operation(); print("PASS \(name)") }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        for (name, body) in [
            ("premature EOF", event(["content": "partial"])),
            ("length truncation", event(["content": "partial"], finish: "length") + "data: [DONE]\n\n"),
            ("invalid JSON", "data: {broken\n\n" + "data: [DONE]\n\n"),
            ("JSON server error", "data: {\"error\":{\"message\":\"failed\"}}\n\n"),
            ("SSE error event", "event: error\ndata: {\"message\":\"failed\"}\n\n")
        ] {
            await test(name) {
                SparkHTTPMock.responder = { _ in (200, body) }
                try await requireError { try await Spark.responder([], aoChegar: { _ in }) }
            }
        }
        await test("valid stop without DONE") {
            SparkHTTPMock.responder = { _ in (200, event(["content": "complete"], finish: "stop")) }
            var output = ""
            try await Spark.responder([]) { output += $0 }
            try require(output == "complete", "lost final content")
        }
        await test("DONE without finish is valid") {
            SparkHTTPMock.responder = { _ in (200, event(["content": "complete"]) + "data: [DONE]\n\n") }
            var output = ""
            try await Spark.responder([]) { output += $0 }
            try require(output == "complete", "lost final content")
        }
        await test("availability checks expected model") {
            SparkHTTPMock.responder = { _ in (200, "{\"data\":[{\"id\":\"other-model\"}]}") }
            let available = await Spark.disponivel()
            try require(!available, "accepted unrelated model")
        }
        for (name, invalid) in [
            ("unknown tool", tool("call_1", "unknown")),
            ("empty id", tool("")),
            ("empty name", tool("call_1", "")),
            ("non-string arguments", tool("call_1", "allowed", [:])),
            ("missing id", ["type": "function", "function": ["name": "allowed", "arguments": "{}"]]),
            ("missing arguments", ["id": "call_1", "type": "function", "function": ["name": "allowed"]]),
            ("malformed arguments", tool("call_1", "allowed", "{broken")),
            ("array arguments", tool("call_1", "allowed", "[]"))
        ] {
            await test(name) {
                var effects = 0
                SparkHTTPMock.responder = { request in (200, completion(request, calls: [invalid])) }
                try await requireError {
                    _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10) { _, _ in effects += 1; return "effect" }
                }
                try require(effects == 0, "invalid call caused effect")
            }
        }
        await test("all calls validated before effects") {
            var effects = 0
            SparkHTTPMock.responder = { request in (200, completion(request, calls: [tool(), tool("call_2", "unknown")])) }
            try await requireError { _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10) { _, _ in effects += 1; return "effect" } }
            try require(effects == 0, "partial validation allowed effect")
        }
        await test("duplicate ids rejected before effects") {
            var effects = 0
            SparkHTTPMock.responder = { request in (200, completion(request, calls: [tool(), tool()])) }
            try await requireError { _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10) { _, _ in effects += 1; return "effect" } }
            try require(effects == 0, "duplicate ids caused an effect")
        }
        await test("cancellation in clear callback prevents effects") {
            var effects = 0
            SparkHTTPMock.responder = { request in (200, completion(request, calls: [tool()])) }
            let task = Task {
                try await requireError {
                    _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10,
                        executar: { _, _ in effects += 1; return "effect" },
                        aoChamarFerramenta: { withUnsafeCurrentTask { $0?.cancel() } })
                }
            }
            try await task.value
            try require(effects == 0, "cancelled callback caused an effect")
        }
        for scenario in ["invalid tool", "length after tool", "fourth round tool"] {
            await test("clear draft before failure: \(scenario)") {
                var ui = ""
                var clears = 0
                var effects = 0
                SparkHTTPMock.responder = { _ in
                    let call = scenario == "invalid tool" ? tool("call_1", "unknown") : tool()
                    var fragment = call; fragment["index"] = 0
                    let finish = scenario == "length after tool" ? "length" : "tool_calls"
                    return (200, event(["content": "draft"]) + event(["tool_calls": [fragment]]) + event(finish: finish) + "data: [DONE]\n\n")
                }
                try await requireError {
                    _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10,
                        executar: { _, _ in effects += 1; return "effect" },
                        aoChegar: { ui += $0 }, aoChamarFerramenta: { clears += 1; ui = "" })
                }
                try require(ui.isEmpty, "draft remained visible after failure")
                try require(clears == (scenario == "fourth round tool" ? 4 : 1), "clear did not happen once per detected tool round")
                try require(effects == (scenario == "fourth round tool" ? 3 : 0), "unexpected tool effects")
            }
        }
        await test("fragmented tool clears draft and streams final") {
            var ui = ""
            var sequence: [String] = []
            var effects = 0
            var round = 0
            var forwardedMessages: [[String: Any]] = []
            SparkHTTPMock.responder = { request in
                round += 1
                if round == 1 {
                    let first: [String: Any] = ["index": 0, "id": "call_", "type": "function", "function": ["name": "allow", "arguments": "{\"q\":"]]
                    let second: [String: Any] = ["index": 0, "id": "1", "function": ["name": "ed", "arguments": "\"value\"}"]]
                    return (200, event(["content": "draft"]) + event(["tool_calls": [first]]) + event(["tool_calls": [second]], finish: "tool_calls") + "data: [DONE]\n\n")
                }
                forwardedMessages = requestBody(request)["messages"] as? [[String: Any]] ?? []
                return (200, event(["content": "fi"]) + event(["content": "nal"], finish: "stop") + "data: [DONE]\n\n")
            }
            let result = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10,
                executar: { name, args in
                    try require(ui.isEmpty, "draft remained before tool effect")
                    try require(name == "allowed" && args == "{\"q\":\"value\"}", "fragment assembly changed call")
                    effects += 1; sequence.append("effect"); return "tool result"
                }, aoChegar: { ui += $0; sequence.append($0) }, aoChamarFerramenta: { ui = ""; sequence.append("clear") })
            try require(result == "final" && ui == "final" && effects == 1, "draft leaked or final text was lost")
            try require(sequence == ["draft", "clear", "effect", "fi", "nal"], "callback order incorrect: \(sequence)")
            try require(forwardedMessages.count == 2, "missing assistant/tool messages")
            try require(forwardedMessages[0]["content"] as? String == "", "draft sent back as final content")
            try require(forwardedMessages[1]["tool_call_id"] as? String == "call_1" && forwardedMessages[1]["content"] as? String == "tool result", "tool result association changed")
        }
        await test("cancellation after tool prevents subsequent effects") {
            var effects = 0
            SparkHTTPMock.responder = { request in (200, completion(request, calls: [tool(), tool("call_2")])) }
            let task = Task {
                try await requireError {
                    _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10) { _, _ in
                        effects += 1
                        withUnsafeCurrentTask { $0?.cancel() }
                        return "effect"
                    }
                }
            }
            try await task.value
            try require(effects == 1, "cancelled operation executed \(effects) tools")
        }
        await test("round limit explicitly fails") {
            var effects = 0
            SparkHTTPMock.responder = { request in (200, completion(request, calls: [tool()])) }
            try await requireError { _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10) { _, _ in effects += 1; return "effect" } }
            try require(effects <= 4, "exceeded round bound")
        }
        await test("tool round requests streaming") {
            var streamed = false
            SparkHTTPMock.responder = { request in
                let body = requestBody(request)
                streamed = body["stream"] as? Bool == true
                return (200, completion(request))
            }
            let result = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10) { _, _ in "effect" }
            try require(streamed && result == "final", "tool conversation did not stream")
        }
        await test("expected model availability") {
            SparkHTTPMock.responder = { _ in (200, "{\"data\":[{\"id\":\"nvidia/Qwen3.6-35B-A3B-NVFP4\"}]}") }
            let available = await Spark.disponivel()
            try require(available, "expected model reported unavailable")
        }
        await test("CRLF and multiline SSE JSON") {
            SparkHTTPMock.responder = { _ in (200, "event: message\r\ndata: {\r\ndata: \"choices\":[{\"delta\":{\"content\":\"complete\"},\"finish_reason\":\"stop\"}]}\r\n\r\n") }
            var output = ""
            try await Spark.responder([]) { output += $0 }
            try require(output == "complete", "CRLF/multiline event lost")
        }
        await test("HTTP error fails") {
            SparkHTTPMock.responder = { _ in (503, "unavailable") }
            try await requireError { try await Spark.responder([], aoChegar: { _ in }) }
        }
        await test("tool execution failure propagates without retry") {
            var effects = 0
            SparkHTTPMock.responder = { request in (200, completion(request, calls: [tool()])) }
            try await requireError {
                _ = try await Spark.responderComFerramentas([], ferramentas: tools, maxTokens: 10) { _, _ in
                    effects += 1
                    throw SparkTestFailure(description: "execution failed")
                }
            }
            try require(effects == 1, "failed tool was retried")
        }
        print("Spark tests: \(failures) failure(s)")
        exit(failures == 0 ? 0 : 1)
    }
}
