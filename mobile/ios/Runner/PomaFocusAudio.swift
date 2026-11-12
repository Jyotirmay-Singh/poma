import AVFAudio
import Flutter
import MediaPlayer
import UIKit

@_cdecl("pomaFocusAudioEvent")
func pomaFocusAudioEvent(_ kind: Int32, _ owner: Int64, _ generation: Int64, _ epoch: Int64) {
  DispatchQueue.main.async {
    PomaFocusAudioBridge.shared?.event(kind, owner, generation, epoch)
  }
}

/// One process/engine-scoped policy bridge. The native runtime owns the renderer.
final class PomaFocusAudioBridge {
  static var shared: PomaFocusAudioBridge?
  private let channel: FlutterMethodChannel
  private let work = DispatchQueue(label: "dev.poma.poma.focus_audio.resources")
  private let audio = AVAudioSession.sharedInstance()
  private var observers: [NSObjectProtocol] = []
  private var commands: [(MPRemoteCommand, Any)] = []
  private var session: [String: Any] = [:]
  private var eligibleRun: String?
  private var pending: Preparation?
  private var title = "Focus sounds"
  private var preview = false
  private var route = ""
  private static let assets = [
    "", "tibetan_bells.ogg", "waterfall.ogg", "ocean_waves.ogg",
    "forest_birds.ogg", "calming_rain.ogg", "om_chanting.ogg"
  ]
  private static let titles = [
    "", "Tibetan bells", "Waterfall", "Ocean waves",
    "Forest birds", "Calming rain", "OM chanting"
  ]
  private final class Preparation {
    let owner, generation, epoch, deadline: Int64
    let sound: Int
    let result: FlutterResult
    var finished = false
    init(_ args: [String: Any], _ result: @escaping FlutterResult) {
      owner = (args["owner"] as? NSNumber)?.int64Value ?? -1
      generation = (args["generation"] as? NSNumber)?.int64Value ?? -1
      epoch = (args["epoch"] as? NSNumber)?.int64Value ?? -1
      deadline = (args["startupDeadline"] as? NSNumber)?.int64Value ?? 0
      sound = (args["sound"] as? NSNumber)?.intValue ?? 0
      self.result = result
    }
    var current: Bool {
      owner == pomaMobileOwner() && generation == pomaMobileGeneration() &&
        epoch == pomaMobileEpoch() && deadline > pomaMobileNow()
    }
  }
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dev.poma.poma/focus_audio", binaryMessenger: messenger)
    Self.shared = self
    pomaMobileSetEvent(pomaFocusAudioEvent)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: audio, queue: .main) { notification in
      let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
      if type == AVAudioSession.InterruptionType.began.rawValue { pomaMobileInterrupt(1) }
      // An interruption end is never an authorization to resume.
    })
    observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: audio, queue: .main) { [weak self] _ in
      guard let self = self else { return }
      let next = self.outputRoute()
      if next != self.route && pomaMobileBusy() != 0 { pomaMobileInterrupt(3) }
      self.route = next
    })
    observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: audio, queue: .main) { _ in pomaMobileInterrupt(6) })
    route = outputRoute()
    let remote = MPRemoteCommandCenter.shared()
    for (command, action) in [(remote.playCommand, "play"), (remote.pauseCommand, "pause"), (remote.stopCommand, "stop")] {
      let token = command.addTarget { [weak self] _ in
        let handle: () -> MPRemoteCommandHandlerStatus = { [weak self] in
          guard let self = self else { return .commandFailed }
          return self.control(action) ? .success : .commandFailed
        }
        return Thread.isMainThread ? handle() : DispatchQueue.main.sync(execute: handle)
      }
      commands.append((command, token))
    }
    remote.nextTrackCommand.isEnabled = false
    remote.previousTrackCommand.isEnabled = false
    remote.changePlaybackPositionCommand.isEnabled = false
    remote.skipForwardCommand.isEnabled = false
    remote.skipBackwardCommand.isEnabled = false
  }
  private func outputRoute() -> String { audio.currentRoute.outputs.map { $0.uid }.sorted().joined(separator: "|") }
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let owner = (args["owner"] as? NSNumber)?.int64Value ?? -1
    guard owner == pomaMobileOwner() else { result(FlutterError(code: "cancelled", message: "Sound request expired.", details: nil)); return }
    switch call.method {
    case "session":
      session = args
      if args["restoration"] as? Bool == true || args["running"] as? Bool != true || eligibleRun != args["runId"] as? String { eligibleRun = nil }
      updateMedia(); result(nil)
    case "prepare":
      let request = Preparation(args, result)
      guard pending == nil, (1..<Self.assets.count).contains(request.sound), request.current else {
        result(FlutterError(code: "cancelled", message: "Sound request expired.", details: nil)); return
      }
      pending = request
      preview = args["preview"] as? Bool == true
      eligibleRun = !preview && session["running"] as? Bool == true ? args["runId"] as? String : nil
      title = Self.titles[request.sound]
      do {
        // Configuration is reapplied after backend initialization/reset, and only
        // this explicit request activates the shared audio session.
        try audio.setCategory(.playback, mode: .default, options: [])
        try audio.setActive(true)
      } catch { finish(request, nil, "Audio is in use. Play sounds when ready."); return }
      DispatchQueue.main.asyncAfter(deadline: .now() + .microseconds(Int(min(10_000_000, max(1, request.deadline - pomaMobileNow()))))) { [weak self, weak request] in
        guard let self = self, let request = request, !request.finished, self.pending === request else { return }
        pomaMobileInterrupt(7)
        self.finish(request, nil, "Sound preparation timed out. Retry.")
      }
      work.async { [weak self] in
        guard let self = self else { return }
        var source: Int64 = 0
        let key = FlutterDartProject.lookupKey(forAsset: "assets/audio/\(Self.assets[request.sound])")
        if request.current, let path = Bundle.main.path(forResource: key, ofType: nil),
           let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attributes[.size] as? NSNumber,
           size.intValue > 0, size.intValue <= 4 * 1024 * 1024,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)), request.current {
          source = data.withUnsafeBytes { bytes in
            pomaMobilePrepare(request.owner, request.generation, request.epoch, request.deadline,
                Int32(request.sound), bytes.bindMemory(to: UInt8.self).baseAddress, Int32(data.count))
          }
        }
        let prepared = source
        DispatchQueue.main.async {
          if request.finished || !request.current {
            if prepared > 0 { self.work.async { pomaMobileRelease(request.owner, prepared) } }
            self.finish(request, nil, "Sound request was cancelled.")
          } else { self.finish(request, prepared > 0 ? prepared : nil, "Sound could not be prepared. Retry.") }
        }
      }
    case "start":
      let code = pomaMobileStart(owner, (args["source"] as? NSNumber)?.int64Value ?? 0,
          (args["generation"] as? NSNumber)?.int64Value ?? -1, (args["epoch"] as? NSNumber)?.int64Value ?? -1,
          (args["deadline"] as? NSNumber)?.int64Value ?? 0, (args["volume"] as? NSNumber)?.floatValue ?? 0)
      cleanup(); updateMedia(); result(code)
    case "release":
      let source = (args["source"] as? NSNumber)?.int64Value ?? 0
      work.async { [weak self] in
        pomaMobileRelease(owner, source)
        DispatchQueue.main.async { self?.cleanup(); result(nil) }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func finish(_ request: Preparation, _ source: Int64?, _ error: String?) {
    guard !request.finished else { return }
    request.finished = true
    if pending === request { pending = nil }
    if let source = source { request.result(source) }
    else { request.result(FlutterError(code: "audio", message: error, details: nil)) }
    cleanup(); updateMedia()
  }
  func event(_ kind: Int32, _ owner: Int64, _ generation: Int64, _ epoch: Int64) {
    guard owner == pomaMobileOwner(), epoch >= pomaMobileEpoch() else {
      if (session["owner"] as? NSNumber)?.int64Value != pomaMobileOwner() { session = [:]; eligibleRun = nil }
      cleanup(); updateMedia(); return
    }
    if kind != 7 { channel.invokeMethod("event", arguments: ["kind": kind, "owner": owner, "generation": generation, "epoch": epoch]) }
    cleanup(); updateMedia()
  }
  private func control(_ action: String) -> Bool {
    pomaMobileReconcile()
    if action == "play" && (eligibleRun == nil || eligibleRun != session["runId"] as? String ||
        session["running"] as? Bool != true || ((session["deadline"] as? NSNumber)?.int64Value ?? 0) <= pomaMobileNow()) { updateMedia(); return false }
    let owner = pomaMobileOwner(), generation = pomaMobileGeneration()
    if action != "play" { pomaMobileInterrupt(7) }
    channel.invokeMethod("media", arguments: ["owner": owner, "generation": generation, "epoch": pomaMobileEpoch(),
        "runId": session["runId"] ?? NSNull(), "segment": session["segment"] ?? NSNull(), "action": action])
    return true
  }
  private func updateMedia() {
    let playing = pomaMobilePlaying() != 0
    let eligible = eligibleRun != nil && eligibleRun == session["runId"] as? String &&
        session["running"] as? Bool == true && ((session["deadline"] as? NSNumber)?.int64Value ?? 0) > pomaMobileNow()
    MPNowPlayingInfoCenter.default().nowPlayingInfo = playing || eligible ? [
      MPMediaItemPropertyTitle: title, MPMediaItemPropertyArtist: "Poma",
      MPNowPlayingInfoPropertyIsLiveStream: true, MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0
    ] : nil
    let remote = MPRemoteCommandCenter.shared()
    remote.playCommand.isEnabled = eligible && !playing
    remote.pauseCommand.isEnabled = playing
    remote.stopCommand.isEnabled = playing || eligible
  }
  private func cleanup() {
    if pomaMobileBusy() == 0 && pending?.current != true {
      try? audio.setActive(false, options: .notifyOthersOnDeactivation)
    }
  }
  func foreground() { pomaMobileReconcile(); cleanup(); updateMedia() }
  func background() { if preview && pomaMobileBusy() != 0 { pomaMobileInterrupt(0) } }
  deinit {
    channel.setMethodCallHandler(nil)
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    for (command, token) in commands { command.removeTarget(token) }
  }
}
