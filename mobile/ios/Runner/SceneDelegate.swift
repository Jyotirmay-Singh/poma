import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneWillEnterForeground(_ scene: UIScene) {
    PomaFocusAudioBridge.shared?.foreground()
    super.sceneWillEnterForeground(scene)
  }
  override func sceneDidEnterBackground(_ scene: UIScene) {
    PomaFocusAudioBridge.shared?.background()
    super.sceneDidEnterBackground(scene)
  }
}
