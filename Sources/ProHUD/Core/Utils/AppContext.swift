//
//  AppContext.swift
//
//
//  Created by xaoxuu on 2023/8/5.
//

import UIKit

public protocol Workspace {}

extension UIWindowScene: Workspace {}
extension UIView: Workspace {}
extension UIViewController: Workspace {}

extension Workspace {
    var windowScene: UIWindowScene? {
        if let self = self as? UIWindowScene {
            return self
        } else if let self = self as? UIWindow {
            return self.windowScene
        } else if let self = self as? UIView {
            return self.window?.windowScene
        } else if let self = self as? UIViewController {
            return self.view.window?.windowScene
        }
        return nil
    }
}

public struct AppContext {
    
    private static var storedAppWindowScene: UIWindowScene?
    
    /// 一个scene关联一个toast
    static var toastWindows: [UIWindowScene: [ToastWindow]] = [:]
    static var alertWindow: [UIWindowScene: AlertWindow] = [:]
    static var sheetWindows: [UIWindowScene: [SheetWindow]] = [:]
    static var capsuleWindows: [UIWindowScene: [CapsuleViewModel.Position: CapsuleWindow]] = [:]
    static var capsuleInQueue: [CapsuleTarget] = []
    
    static var current: AppContext? {
        guard let windowScene = windowScene else { return nil }
        if let ctx = allContexts[windowScene] {
            return ctx
        } else {
            let ctx: AppContext = .init(windowScene: windowScene)
            allContexts[windowScene] = ctx
            return ctx
        }
    }
    static var allContexts = [UIWindowScene: AppContext]()
    private let windowScene: UIWindowScene
    
    private init(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }
    
    /// 单窗口应用无需设置，多窗口应用需要指定显示到哪个windowScene上
    /// workspace可以是windowScene/window/view/viewController
    public static var workspace: Workspace? {
        get { windowScene }
        set {
            windowScene = newValue?.windowScene
        }
    }
    
}

extension AppContext {
    
    static var foregroundActiveWindowScenes: [UIWindowScene] {
        return UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).filter({ scene in
            if #available(iOS 16.0, *) {
                if scene.activationState == .foregroundActive && scene.session.role != .windowExternalDisplayNonInteractive {
                    return true
                }
            } else {
                if scene.activationState == .foregroundActive && scene.session.role != .windowExternalDisplay {
                    return true
                }
            }
            return false
        })
    }
    
    /// 获取所有外部显示的WindowScene（包括AirPlay）
    static var externalWindowScenes: [UIWindowScene] {
        return UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).filter({ scene in
            if #available(iOS 16.0, *) {
                return scene.activationState == .foregroundActive && scene.session.role == .windowExternalDisplayNonInteractive
            } else {
                return scene.activationState == .foregroundActive && scene.session.role == .windowExternalDisplay
            }
        })
    }
    
    ///设置外观
    public static var overrideUserInterfaceStyle: UIUserInterfaceStyle = .dark
    
    /// 外部窗口信息（由外部设置）
    private static var externalWindowInfo: (window: UIWindow, isActive: Bool)?
    
    /// 设置外部窗口信息
    /// - Parameters:
    ///   - window: 外部窗口
    ///   - isActive: 是否激活外部窗口显示
    public static func setExternalWindow(_ window: UIWindow?, isActive: Bool) {
        if let window = window, isActive {
            externalWindowInfo = (window: window, isActive: true)
        } else {
            externalWindowInfo = nil
        }
    }
    
    /// 检查是否应该使用外部窗口显示ProHUD内容
    static var shouldUseExternalWindow: Bool {
        guard let info = externalWindowInfo else { return false }
        return info.isActive && !info.window.isHidden
    }
    
    /// 获取外部窗口的WindowScene
    static var externalWindowScene: UIWindowScene? {
        guard shouldUseExternalWindow else { return nil }
        return externalWindowInfo?.window.windowScene
    }
    
    /// 如果设置了workspace，就是workspace所对应的windowScene，否则就是最后一个打开的应用程序窗口的windowScene
    /// 当AirPlay投屏且外部窗口可见时，优先使用外部窗口场景
    static var windowScene: UIWindowScene? {
        set { storedAppWindowScene = newValue }
        get {
            // 如果有明确设置的workspace，使用它
            if let ws = storedAppWindowScene {
                return ws
            }
            
            // 检查是否应该使用外部窗口
            if let externalScene = externalWindowScene {
                return externalScene
            }
            
            // 默认使用最后一个前台活跃的窗口场景
            return foregroundActiveWindowScenes.last
        }
    }
    
    /// 所有的窗口
    static var windows: [UIWindow] {
        windowScene?.windows ?? UIApplication.shared.windows
    }
    
    /// 可见的窗口
    static var visibleWindows: [UIWindow] {
        windows.filter { $0.isHidden == false }
    }
    
    /// App主程序窗口
    static var appWindow: UIWindow? {
        // 如果应该使用外部窗口，优先返回外部窗口
        if shouldUseExternalWindow, let info = externalWindowInfo {
            return info.window
        }
        
        // 否则返回正常的主程序窗口
        return visibleWindows.filter { window in
            return "\(type(of: window))" == "UIWindow" && window.windowLevel == .normal
        }.first
    }
    
    /// Ask the app window to re-apply rotation after an overlay is dismissed.
    /// iOS 26 keeps `isInterfaceOrientationLocked` until a visible VC reports false.
    static func restoreInterfaceRotationIfNeeded() {
        guard #available(iOS 26.0, *) else { return }
        let root = appWindow?.rootViewController
        root?.setNeedsUpdateOfSupportedInterfaceOrientations()
        root?.setNeedsUpdateOfPrefersInterfaceOrientationLocked()
    }
    
    /// App主程序窗口的尺寸
    static var appBounds: CGRect {
        appWindow?.bounds ?? UIScreen.main.bounds
    }
    
    /// App主程序窗口的安全边距
    static var safeAreaInsets: UIEdgeInsets { 
        // 外部窗口通常没有安全边距，或者使用iPad的逻辑
        if shouldUseExternalWindow {
            return .zero // 外部显示器通常没有安全边距
        }
        return appWindow?.safeAreaInsets ?? .zero 
    }
    
}

// MARK: - instance manage

extension AppContext {
    var sheetWindows: [SheetWindow] {
        Self.sheetWindows[windowScene] ?? []
    }
    var toastWindows: [ToastWindow] {
        Self.toastWindows[windowScene] ?? []
    }
    var capsuleWindows: [CapsuleViewModel.Position: CapsuleWindow] {
        Self.capsuleWindows[windowScene] ?? [:]
    }
    var alertWindow: AlertWindow? {
        Self.alertWindow[windowScene]
    }
}

extension AppContext {
    private static var appWindowPortraitSnapshot: UIImageView? = nil
    private static var appWindowLandscapeSnapshot: UIImageView? = nil
    private static var appWindowSnapshotView: UIImageView? {
        get {
            isDevicePortrait ? appWindowPortraitSnapshot : appWindowLandscapeSnapshot
        }
        set {
            if isDevicePortrait {
                appWindowPortraitSnapshot = newValue
            } else {
                appWindowLandscapeSnapshot = newValue
            }
        }
    }
    
    static func updateAppWindowSnapshotIfNeed(afterScreenUpdates: Bool = false) {
        guard appWindowSnapshotView == nil else { return }
        
        if let appWindow {
            let renderer = UIGraphicsImageRenderer(bounds: appWindow.bounds)
            let image = renderer.image { _ in
                appWindow.drawHierarchy(in: appWindow.bounds, afterScreenUpdates: afterScreenUpdates)
            }
            let snapshotView = UIImageView(image: image)
            snapshotView.contentMode = .scaleToFill
            snapshotView.layer.masksToBounds = true
            AppContext.appWindow?.addSubview(snapshotView)
            snapshotView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            appWindowSnapshotView = snapshotView
        }
    }
    
    static func removeStackDepthEffectSnapshot() {
        appWindowPortraitSnapshot?.removeFromSuperview()
        appWindowLandscapeSnapshot?.removeFromSuperview()
        appWindowPortraitSnapshot = nil
        appWindowLandscapeSnapshot = nil
        resumeAppWindowVisible()
    }
    
    static func resumeAppWindowVisible() {
        AppContext.appWindow?.rootViewController?.view.alpha = 1
        appWindowPortraitSnapshot?.isHidden = true
        appWindowLandscapeSnapshot?.isHidden = true
    }
    
    ///0 to 1 window gradually enlarges, and when it's at its maximum, it returns to its original size.
    static func appWindowStackDepthEffect(progress: CGFloat) {
        var fixProgress = max(progress, 0)
        fixProgress = min(fixProgress, 1)
        
        if isDevicePortrait {
            appWindowLandscapeSnapshot?.isHidden = true
            appWindowPortraitSnapshot?.isHidden = false
        } else {
            appWindowLandscapeSnapshot?.isHidden = false
            appWindowPortraitSnapshot?.isHidden = true
        }
        AppContext.appWindow?.rootViewController?.view.alpha = 0
        
        if isPhonePortrait {
            appWindowSnapshotView?.transform = .init(translationX: 0, y: 8-(8*progress)).scaledBy(x: 0.9+0.1*progress, y: 0.9+0.1*progress)
        } else {
            appWindowSnapshotView?.transform = .init(scaleX: 0.92+0.08*progress, y: 0.92+0.08*progress)
        }
        
        if hasNotch {
            //16~39
            appWindowSnapshotView?.layer.cornerRadiusWithContinuous = 16+((39-16)*progress)
        } else {
            //16~4
            appWindowSnapshotView?.layer.cornerRadiusWithContinuous = 16-((16-4)*progress)
        }
    }
}
 
