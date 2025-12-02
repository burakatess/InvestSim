import Foundation

/// Service to fetch Yahoo Finance cookie and crumb for authentication
final class YahooCrumbService {
    static let shared = YahooCrumbService()

    private var cookie: String?
    private var crumb: String?
    private var isFetching = false
    private let semaphore = DispatchSemaphore(value: 1)

    private init() {}

    /// Get valid crumb and cookie, fetching if necessary
    func getCrumb(completion: @escaping (Result<(cookie: String, crumb: String), Error>) -> Void) {
        if let cookie = cookie, let crumb = crumb {
            completion(.success((cookie, crumb)))
            return
        }

        fetchCrumb(completion: completion)
    }

    private func fetchCrumb(
        completion: @escaping (Result<(cookie: String, crumb: String), Error>) -> Void
    ) {
        guard !isFetching else {
            // Simple debounce - in production might want to queue callbacks
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.getCrumb(completion: completion)
            }
            return
        }

        isFetching = true

        // 1. Get Cookie
        let url = URL(string: "https://fc.yahoo.com")!
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }

            if let httpResponse = response as? HTTPURLResponse,
                let fields = httpResponse.allHeaderFields as? [String: String],
                let url = response?.url
            {

                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)

                if let validCookie = cookies.first(where: { $0.name == "A3" }) {
                    self.cookie = "\(validCookie.name)=\(validCookie.value)"
                    self.fetchCrumbValue(cookie: self.cookie!, completion: completion)
                    return
                }
            }

            // Fallback: Try another endpoint if fc.yahoo.com fails or doesn't set cookie
            self.fetchCrumbValue(cookie: "", completion: completion)

        }.resume()
    }

    private func fetchCrumbValue(
        cookie: String,
        completion: @escaping (Result<(cookie: String, crumb: String), Error>) -> Void
    ) {
        let url = URL(string: "https://query1.finance.yahoo.com/v1/test/getcrumb")!
        var request = URLRequest(url: url)
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.isFetching = false

            if let data = data, let crumb = String(data: data, encoding: .utf8), !crumb.isEmpty {
                self.crumb = crumb
                self.cookie = cookie  // Ensure we keep the cookie that worked
                print("🍪 Yahoo Crumb fetched: \(crumb)")
                completion(.success((cookie, crumb)))
            } else {
                print("❌ Failed to fetch Yahoo Crumb")
                completion(
                    .failure(
                        NSError(
                            domain: "YahooCrumb", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get crumb"])))
            }
        }.resume()
    }
}
