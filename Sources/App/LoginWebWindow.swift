import Cocoa
import WebKit
import CryptoKit

class LoginWebWindowController: NSWindowController, WKNavigationDelegate, WKUIDelegate {
    var webView: WKWebView!
    var onSpotifyTokenObtained: ((String) -> Void)?
    var onSoundCloudTokenObtained: ((String) -> Void)?
    var isSpotify: Bool = false
    var codeVerifier: String = ""
    
    convenience init(isSpotify: Bool) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = isSpotify ? "Вход в Spotify" : "Вход в SoundCloud"
        self.init(window: window)
        self.isSpotify = isSpotify
        
        let config = WKWebViewConfiguration()
        
        self.webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        self.webView.autoresizingMask = [.width, .height]
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        window.contentView?.addSubview(self.webView)
        
        if isSpotify {
            // Generate PKCE values
            let verifierBytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
            let verifier = Data(verifierBytes).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
                .trimmingCharacters(in: .whitespaces)
            self.codeVerifier = verifier
            
            let challenge: String
            if let data = verifier.data(using: .ascii) {
                let hash = SHA256.hash(data: data)
                challenge = Data(hash).base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else {
                challenge = ""
            }
            
            let authUrl = "https://accounts.spotify.com/authorize?client_id=2e16d09b68e2447990d0ef06ad94a8df&redirect_uri=https://spotify.com&response_type=code&scope=user-read-private%20playlist-read-private&code_challenge_method=S256&code_challenge=\(challenge)"
            if let url = URL(string: authUrl) {
                webView.load(URLRequest(url: url))
            }
        } else {
            let authUrl = "https://soundcloud.com/signin"
            if let url = URL(string: authUrl) {
                webView.load(URLRequest(url: url))
            }
            startSoundCloudCookiePolling()
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if isSpotify, let url = navigationAction.request.url {
            if checkForSpotifyToken(url: url) {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isSpotify, let url = webView.url {
            _ = checkForSpotifyToken(url: url)
        }
    }
    
    // WKUIDelegate popup blocker bypass: opens popup inside the same webView (crucial for Google/Facebook/Apple OAuth logins)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    private func checkForSpotifyToken(url: URL) -> Bool {
        if let host = url.host, host.contains("spotify.com") {
            if let query = url.query {
                let params = parseFragment(query)
                if let code = params["code"] {
                    exchangeCodeForToken(code: code)
                    return true
                }
            }
        }
        return false
    }
    
    private func exchangeCodeForToken(code: String) {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyComponents = [
            "client_id": "2e16d09b68e2447990d0ef06ad94a8df",
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": "https://spotify.com",
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = bodyComponents
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
            
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                DispatchQueue.main.async {
                    self.onSpotifyTokenObtained?(token)
                    self.close()
                }
            }
        }
        task.resume()
    }
    
    private func parseFragment(_ fragment: String) -> [String: String] {
        var params: [String: String] = [:]
        let pairs = fragment.components(separatedBy: "&")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                params[parts[0]] = parts[1]
            }
        }
        return params
    }
    
    private func startSoundCloudCookiePolling() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.window?.isVisible == false {
                timer.invalidate()
                return
            }
            
            let cookieStore = self.webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    if cookie.domain.contains("soundcloud.com"), cookie.name == "oauth_token" {
                        DispatchQueue.main.async {
                            self.onSoundCloudTokenObtained?(cookie.value)
                            timer.invalidate()
                            self.close()
                        }
                        break
                    }
                }
            }
        }
    }
}
