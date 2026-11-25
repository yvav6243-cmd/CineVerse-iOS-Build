import SwiftUI
import WebKit

@MainActor
public final class WebMediaBridgeController: NSObject, WKScriptMessageHandler {
    public weak var webView: WKWebView?
    public var onReady: ((Double, Int, Int) -> Void)?
    public var onTimeUpdate: ((Double, Double, Bool) -> Void)?
    public var onBufferingChanged: ((Bool) -> Void)?
    public var onPlayStateChanged: ((Bool) -> Void)?
    public var onEnded: (() -> Void)?
    public var onError: ((String) -> Void)?

    public private(set) var currentLoadedURL: URL?
    public private(set) var desiredPlaying: Bool = false
    private var currentScalingMode: VideoScalingMode = .fit
    private var pendingStartTime: Double = 0

    public func loadStream(
        url: URL,
        startTime: Double,
        rate: Float,
        volume: Float,
        scalingMode: VideoScalingMode = .fit,
        autoPlay: Bool = true
    ) {
        currentLoadedURL = url
        pendingStartTime = max(0, startTime)
        currentScalingMode = scalingMode
        desiredPlaying = autoPlay

        guard let webView else { return }
        let escapedURL = url.absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let cssRule = Self.cssRule(for: scalingMode)
        let desiredLiteral = autoPlay ? "true" : "false"

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html, body { margin:0; padding:0; width:100%; height:100%; background:#000; overflow:hidden; -webkit-user-select:none; display:flex; align-items:center; justify-content:center; }
        video { \(cssRule) background:#000; pointer-events:none; }
        </style>
        </head>
        <body>
        <video id="cvv" playsinline webkit-playsinline preload="auto" src="\(escapedURL)"></video>
        <script>
        (function() {
            const v = document.getElementById('cvv');
            window.__cvDesiredPlaying = \(desiredLiteral);
            v.volume = \(max(0, min(1, volume)));
            v.playbackRate = \(rate);
            const post = (payload) => {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cvbridge) {
                    window.webkit.messageHandlers.cvbridge.postMessage(payload);
                }
            };
            v.addEventListener('loadedmetadata', () => {
                if (\(pendingStartTime) > 1 && isFinite(v.duration) && \(pendingStartTime) < v.duration) {
                    v.currentTime = \(pendingStartTime);
                }
                post({ type: 'ready', duration: v.duration || 0, width: v.videoWidth || 0, height: v.videoHeight || 0 });
                if (window.__cvDesiredPlaying) {
                    v.play().catch(() => {});
                } else {
                    v.pause();
                }
            });
            v.addEventListener('timeupdate', () => {
                let buf = 0;
                if (v.buffered && v.buffered.length > 0) {
                    buf = v.buffered.end(v.buffered.length - 1);
                }
                post({ type: 'time', current: v.currentTime || 0, buffered: buf, paused: v.paused, width: v.videoWidth || 0, height: v.videoHeight || 0 });
            });
            v.addEventListener('play', () => {
                if (!window.__cvDesiredPlaying) {
                    v.pause();
                    return;
                }
                post({ type: 'state', paused: false });
            });
            v.addEventListener('pause', () => post({ type: 'state', paused: true }));
            v.addEventListener('waiting', () => post({ type: 'buffering', active: true }));
            v.addEventListener('playing', () => post({ type: 'buffering', active: false }));
            v.addEventListener('canplay', () => post({ type: 'buffering', active: false }));
            v.addEventListener('ended', () => post({ type: 'ended' }));
            v.addEventListener('error', () => post({ type: 'error', message: 'Unable to decode WebM/DASH stream.' }));
        })();
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://commons.wikimedia.org"))
    }

    public func setDesiredPlaying(_ playing: Bool) {
        desiredPlaying = playing
        let literal = playing ? "true" : "false"
        webView?.evaluateJavaScript("window.__cvDesiredPlaying=\(literal);", completionHandler: nil)
    }

    public func play() {
        setDesiredPlaying(true)
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.play().catch(()=>{});}", completionHandler: nil)
    }

    public func pause() {
        setDesiredPlaying(false)
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.pause();}", completionHandler: nil)
    }

    public func seek(to seconds: Double) {
        let clamped = max(0, seconds)
        pendingStartTime = clamped
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.currentTime=\(clamped);}", completionHandler: nil)
    }

    public func setRate(_ rate: Float) {
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.playbackRate=\(rate);}", completionHandler: nil)
    }

    public func setVolume(_ volume: Float) {
        let clamped = max(0, min(1, volume))
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){v.volume=\(clamped);}", completionHandler: nil)
    }

    public func setScalingMode(_ mode: VideoScalingMode) {
        guard currentScalingMode != mode else { return }
        currentScalingMode = mode
        let cssJS = Self.cssMutationJS(for: mode)
        webView?.evaluateJavaScript("var v=document.getElementById('cvv'); if(v){\(cssJS)}", completionHandler: nil)
    }

    public func teardown() {
        desiredPlaying = false
        currentLoadedURL = nil
        webView?.evaluateJavaScript("window.__cvDesiredPlaying=false; var v=document.getElementById('cvv'); if(v){v.pause(); v.removeAttribute('src'); v.load();}", completionHandler: nil)
    }

    private static func cssRule(for mode: VideoScalingMode) -> String {
        switch mode {
        case .fit:
            return "width:100%; height:100%; object-fit:contain;"
        case .fill:
            return "width:100%; height:100%; object-fit:cover;"
        case .original:
            return "width:auto; height:auto; max-width:100%; max-height:100%; object-fit:none;"
        }
    }

    private static func cssMutationJS(for mode: VideoScalingMode) -> String {
        switch mode {
        case .fit:
            return "v.style.width='100%'; v.style.height='100%'; v.style.maxWidth=''; v.style.maxHeight=''; v.style.objectFit='contain';"
        case .fill:
            return "v.style.width='100%'; v.style.height='100%'; v.style.maxWidth=''; v.style.maxHeight=''; v.style.objectFit='cover';"
        case .original:
            return "v.style.width='auto'; v.style.height='auto'; v.style.maxWidth='100%'; v.style.maxHeight='100%'; v.style.objectFit='none';"
        }
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
        let active = dict["active"] as? Bool ?? false
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
            case "buffering":
                self.onBufferingChanged?(active)
            case "state":
                self.onPlayStateChanged?(!paused)
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
    let rate: Float
    let volume: Float
    let scalingMode: VideoScalingMode

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
        controller.loadStream(
            url: streamURL,
            startTime: 0,
            rate: rate,
            volume: volume,
            scalingMode: scalingMode,
            autoPlay: controller.desiredPlaying
        )
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        if controller.currentLoadedURL != streamURL {
            controller.loadStream(
                url: streamURL,
                startTime: 0,
                rate: rate,
                volume: volume,
                scalingMode: scalingMode,
                autoPlay: controller.desiredPlaying
            )
        } else {
            controller.setScalingMode(scalingMode)
        }
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "cvbridge")
    }
}
