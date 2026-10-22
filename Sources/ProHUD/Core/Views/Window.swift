//
//  Window.swift
//  
//
//  Created by xaoxuu on 2022/9/1.
//

import UIKit
import SnapKit

/// Placeholder root before the real overlay controller is installed.
/// Uses the host mask so this window cannot rotate away from the app.
class OverlayRootViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if let provider = AppContext.supportedInterfaceOrientations {
            return provider()
        }
        return super.supportedInterfaceOrientations
    }
    
    @available(iOS 26.0, *)
    override var prefersInterfaceOrientationLocked: Bool {
        if let provider = AppContext.prefersInterfaceOrientationLocked {
            return provider()
        }
        return super.prefersInterfaceOrientationLocked
    }
    
    open override var prefersStatusBarHidden: Bool {
        if let action = AppContext.prefersStatusBarHidden, let result = action(presentedViewController) {
            return result
        }
        return super.prefersStatusBarHidden
    }
}

class Window: UIWindow {
    
    lazy var backgroundView: UIView = {
        let v = UIView()
        v.backgroundColor = .black.withAlphaComponent(0.6)
        v.alpha = 0
        return v
    }()
    
    var usingBackground: Bool { false }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    lazy var vc: UIViewController = OverlayRootViewController()
    
    func setup() {
        backgroundColor = .clear
        overrideUserInterfaceStyle = AppContext.overrideUserInterfaceStyle
        
        if usingBackground {
            insertSubview(backgroundView, at: 0)
            backgroundView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        rootViewController = vc
        if #available(iOS 26.0, *) {
            // Stay hidden until the real root is installed. makeKeyAndVisible()
            // here would size the window from the physical device orientation.
        } else {
            makeKeyAndVisible()
            resignKey()
        }
    }
    
    /// iOS 26 only: copy the scene's interface bounds so the overlay does not start in device-native portrait.
    /// In Tabletop the scene is still the full inner display, so follow the app window's top pane instead.
    func matchSceneGeometry() {
        guard #available(iOS 26.0, *) else { return }
        transform = .identity
        if AppContext.isPhoneDuoTabletopMode, let appFrame = AppContext.appWindow?.frame, appFrame.width > 1, appFrame.height > 1 {
            frame = appFrame
            return
        }
        guard let scene = windowScene else { return }
        let bounds = scene.coordinateSpace.bounds
        guard !bounds.isEmpty else { return }
        frame = bounds
    }
    
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
