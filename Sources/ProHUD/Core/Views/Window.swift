//
//  Window.swift
//  
//
//  Created by xaoxuu on 2022/9/1.
//

import UIKit
import SnapKit

/// Alert host / placeholder root. Do not lock interface orientation here:
/// iOS 26 would keep the scene locked after the overlay is dismissed.
class OverlayRootViewController: UIViewController {}

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
    func matchSceneGeometry() {
        guard #available(iOS 26.0, *) else { return }
        guard let scene = windowScene else { return }
        let bounds = scene.coordinateSpace.bounds
        guard !bounds.isEmpty else { return }
        transform = .identity
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
