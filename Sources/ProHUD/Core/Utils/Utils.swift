//
//  File.swift
//  
//
//  Created by xaoxuu on 2022/8/29.
//

import UIKit

extension UIImage {
    public convenience init?(inProHUD named: String) {
        self.init(named: named, in: .main, with: .none)
    }
}


/// Compact (phone-portrait-like) layout.
var isPortrait: Bool {
    if AppContext.isPhoneDuoTabletopMode {
        return false
    }
    if AppContext.appBounds.width < 470 {
        return true
    }
    if UIDevice.current.userInterfaceIdiom == .phone {
        if AppContext.windowScene?.interfaceOrientation.isPortrait == true {
            return true
        }
    }
    return false
}

var isDevicePortrait: Bool {
    if AppContext.isPhoneDuoTabletopMode {
        return false
    }
    return AppContext.windowScene?.interfaceOrientation.isPortrait ?? true
}

var isPhonePortrait: Bool {
    if AppContext.isPhoneDuoTabletopMode {
        return false
    }
    return UIDevice.current.userInterfaceIdiom == .phone && (AppContext.windowScene?.interfaceOrientation.isPortrait == true)
}

var hasNotch: Bool {
    let insets: UIEdgeInsets = AppContext.appWindow?.safeAreaInsets ?? .zero
    let orientation = AppContext.appWindow?.windowScene?.interfaceOrientation ?? .portrait
    if orientation == .landscapeRight {
        return insets.left > 20
    } else if orientation == .landscapeLeft {
        return insets.right > 20
    } else if orientation == .portraitUpsideDown {
        return insets.bottom > 20
    }
    return insets.top > 20
}

var isPhoneDuo: Bool {
#if targetEnvironment(simulator)
    return ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"]! == "iPhone19,4"
#else
    var systemInfo = utsname()
    uname(&systemInfo)
    
    let versionCode: String = String(validatingUTF8: NSString(bytes: &systemInfo.machine, length: Int(_SYS_NAMELEN), encoding: String.Encoding.ascii.rawValue)!.utf8String!)!
    return versionCode == "iPhone19,4"
#endif
}

var isPhoneDuoInnerFullScreen: Bool {
    guard isPhoneDuo else { return false }
    guard AppContext.appWindow?.windowScene?.session.role == .windowApplication else { return false }
    let windowMaxDimension = max(AppContext.appBounds.width, AppContext.appBounds.height)
    let isPhoneDuoInner = windowMaxDimension == 951
    var isPhoneDuoSplitView = false
    if let window = AppContext.appWindow, isPhoneDuoInner {
        isPhoneDuoSplitView = !window.screen.bounds.equalTo(AppContext.appBounds)
    }
    return isPhoneDuoInner && !isPhoneDuoSplitView
}

var isPhoneDuoCompactWidth: Bool {
    guard isPhoneDuo else { return false }
    guard AppContext.appWindow?.windowScene?.session.role == .windowApplication else { return false }
    guard let window = AppContext.appWindow else { return false }
    
    let windowMaxDimension = max(window.screen.bounds.width, window.screen.bounds.height)
    let isPhoneDuoOuter = windowMaxDimension == 678
    let isPhoneDuoInner = windowMaxDimension == 951
    
    var isPhoneDuoSplitView = false
    if isPhoneDuoInner {
        isPhoneDuoSplitView = !window.screen.bounds.equalTo(window.bounds)
    }
    
    return (isPhoneDuoOuter && isPortrait) || (isPhoneDuoSplitView && window.safeAreaInsets.right > 0 && !isPortrait)
}

// 层级： Capsule(top) -> Toast -> 原生Alert -> Alert -> Capsule(middle) -> Sheet -> Capsule(bottom)
extension UIWindow.Level {

    public static let phCapsuleTop: UIWindow.Level = .init(rawValue: UIWindow.Level.alert.rawValue + 1005)
    
    public static let phToast: UIWindow.Level = .init(rawValue: UIWindow.Level.alert.rawValue + 1000)
    
    public static let phAlert: UIWindow.Level = .init(rawValue: UIWindow.Level.alert.rawValue - 10)
    
    public static let phCapsuleMiddle: UIWindow.Level = .init(rawValue: UIWindow.Level.alert.rawValue - 15)

    public static let phSheet: UIWindow.Level = .init(rawValue: UIWindow.Level.alert.rawValue - 20)
    
    public static let phCapsuleBottom: UIWindow.Level = .init(rawValue: UIWindow.Level.alert.rawValue - 25)
    
}
