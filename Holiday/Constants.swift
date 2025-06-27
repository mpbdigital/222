struct Constants {
    static let apiKey: String = {
        guard let value = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String else {
            fatalError("RevenueCat API key not found")
        }
        return value
    }()
}
