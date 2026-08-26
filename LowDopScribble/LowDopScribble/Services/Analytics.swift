import TelemetryDeck

enum Analytics {
    static func configure() {
        let config = TelemetryDeck.Config(appID: "738FCE64-D2AE-483A-B5FB-CCCB26BD5E01")
        TelemetryDeck.initialize(config: config)
    }

    static func send(_ event: String, with params: [String: String] = [:]) {
        TelemetryDeck.signal(event, parameters: params)
    }
}
