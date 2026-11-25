import SwiftUI
import WebKit

@MainActor
public final class WebMediaBridgeController: NSObject, WKScriptMessageHandler {
    public weak var webView: WKWebView?
    public var onReady: ((Double, Int, Int) -> Void)?
    public var onTimeUpdate: ((Double, Double, Bool) -> Void)?
    public var onEnded: (() -> Void)?
    public var onError: ((String) -> Void)?

    public private(set) var currentLoadedURL: URL?

    public func loadStream(url: URL, startTime: Double, rate: Float, volume: Float, aspectFill: Bool) {
        guard let webView else { return }
        currentLoadedURL = url
        let escapedURL = url.absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let fitMode = aspectFill ? "cover" : "contain"

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html, body { margin:0; padding:0; width:100%; height:100%; background:#000; overflow:hidden; -webkit-user-select:none; }
        video { width:100%; height:100%; object-fit:\(fitMode); background:#000; pointer-events:none; }
        </style>
        </head>
        <body>
        <video id="cvv" playsinline webkit-playsinline preload="auto" autoplay src="\(escapedURL)"></video>
        <script>
        (function() {
            const v = document.getElementById('cvv');
            v.volume = \(max(0, min(1, volume)));
            v.playbackRate = \(rate);
            const post = (payload) => {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cvbridge) {
                    window.webkit.messageHandlers.cvbridge.postMessage(payload);
                }
            };
            v.addEventListener('loadedmetadata', () => {
                if (\(startTime) > 1 && isFinite(v.duration) && \(startTime) < v.duration) {
                    v.currentTime = \(startTime);
                }
                post({ type: 'ready', duration: v.duration || 0, width: v.videoWidth || 0, height: v.videoHeight || 0 });
                v.play().catch(() => {});
            });
            v.addEventListener('timeupdate', () => {
                let buf = 0;
                if (v.buffered && v.buffered.length > 0) {
                    buf = v.buffered.end(v.buffered.length - 1);
                }
                post({ type: 'time', current: v.currentTime || 0, buffered: buf, paused: v.paused, width: v.videoWidth || 0, height: v.videoHeight || 0 });
            });
            v.addEventListener('waiting', () => post({ type: 'buffering', active: true }));
            v.addEventListener('playing', () => post({ type: 'buffering', active: false }));
            v.addEventListener('ended', () => post({ type: 'ended' }));
            v.addEventListener('error', () => post({ type: 'error', message: 'Unable to decode WebM/DASH stream.' }));
        })();
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://commons.wikimedia.org"))
    }

    public func play() {
        webView?.evaluateJavaScript("document.getElementById('cvv')?.play();", completionHandler: nil)
    }

    public func pause() {
        webView?.evaluateJavaScript("document.getElementById('cvv')?.pause();", completionHandler: nil)
    }

    public func seek(to seconds: Double) {
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.currentTime=\(max(0, seconds));}", completionHandler: nil)
    }

    public func setRate(_ rate: Float) {
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.playbackRate=\(rate);}", completionHandler: nil)
    }

    public func setVolume(_ volume: Float) {
        let clamped = max(0, min(1, volume))
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.volume=\(clamped);}", completionHandler: nil)
    }

    public func setAspectFill(_ fill: Bool) {
        let mode = fill ? "cover" : "contain"
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.style.objectFit='\(mode)';}", completionHandler: nil)
    }

    public func teardown() {
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.pause(); v.removeAttribute('src'); v.load();}", completionHandler: nil)
    }

    public nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }
        let duration = dict["duration"] as? Double ?? 0
        let current = dict["current"] as? Double ?? 0
        let buffered = dict["buffered"] as? Double ?? 0
        let paused = dict["paused"] as? Bool ?? false
        let width = dict["width"] as? Int ?? 0
        let height = dict["height"] as? Int ?? 0
        let errMessage = dict["message"] as? String ?? "Stream error"

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch type {
            case "ready":
                self.onReady?(duration, width, height)
            case "time":
                self.onTimeUpdate?(current, buffered, paused)
                if width > 0 && height > 0 {
                    self.onReady?(duration, width, height)
                }
            case "ended":
                self.onEnded?()
            case "error":
                self.onError?(errMessage)
            default:
                break
            }
        }
    }
}

public struct WebMediaPlayerSurface: UIViewRepresentable {
    let controller: WebMediaBridgeController
    let streamURL: URL
    let startTime: Double
    let rate: Float
    let volume: Float
    let isAspectFill: Bool

    public func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(controller, name: "cvbridge")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        controller.webView = webView
        controller.loadStream(url: streamURL, startTime: startTime, rate: rate, volume: volume, aspectFill: isAspectFill)
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        if controller.currentLoadedURL != streamURL {
            controller.loadStream(url: streamURL, startTime: startTime, rate: rate, volume: volume, aspectFill: isAspectFill)
        } else {
            controller.setAspectFill(isAspectFill)
        }
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "cvbridge")
    }
}
