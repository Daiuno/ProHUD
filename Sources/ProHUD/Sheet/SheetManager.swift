//
//  SheetManager.swift
//  
//
//  Created by xaoxuu on 2022/9/8.
//

import UIKit

extension SheetTarget {
    
    @objc open func push() {
        guard SheetConfiguration.isEnabled else { return }
        let isNew: Bool
        let window: SheetWindow
        var windows = AppContext.current?.sheetWindows ?? []
        if let w = windows.first(where: { $0.sheet == self }) {
            isNew = false
            window = w
            window.sheet = self
            window.windowLevel = .phSheet
        } else {
            window = SheetWindow(sheet: self)
            isNew = true
        }
        window.rootViewController = self
        if #available(iOS 26.0, *) {
            window.matchSceneGeometry()
            setNeedsUpdateOfSupportedInterfaceOrientations()
            setNeedsUpdateOfPrefersInterfaceOrientationLocked()
        }
        
        if windows.contains(window) == false {
            windows.append(window)
            setContextWindows(windows)
        }
        if isNew {
            if #available(iOS 26.0, *) {
                window.layoutIfNeeded()
                _translateOut()
                navEvents[.onViewWillAppear]?(self)
                window.isHidden = false
            } else {
                _translateOut()
                navEvents[.onViewWillAppear]?(self)
            }
            window.sheet.translateIn { [weak self] in
                guard let self = self else { return }
                self.navEvents[.onViewDidAppear]?(self)
            }
        } else {
            if #available(iOS 26.0, *) {
                window.isHidden = false
            }
            view.layoutIfNeeded()
        }
    }
    
    @objc open func pop() {
        guard let window = getContextWindows().first(where: { $0.sheet == self }) else {
            return
        }
        
        if ProcessInfo.processInfo.isiOSAppOnMac {
            //Mac上会闪退 这里使用特殊方式来处理
            // 在 window 释放前，先保存 windowScene（因为 setContextWindows 需要它）
            let scene = window.windowScene
            navEvents[.onViewWillDisappear]?(self)
            window.sheet.translateOut { [weak self] in
                guard let self else { return }
                var windows = self.getContextWindows()
                
                // 先获取回调，避免在 window 释放过程中访问
                let didDisappearCallback = self.navEvents[.onViewDidDisappear]
                
                // 在移除 window 之前，先断开 SheetTarget 对 window 的弱引用
                // 防止在 window deinit 过程中访问弱引用导致崩溃
                self.window = nil
                
                // 先隐藏 window 并移除 rootViewController
                window.isHidden = true
                window.rootViewController = nil
                
                // 从数组中移除 window
                if windows.count > 1 {
                    windows.removeAll { $0 == window }
                } else if windows.count == 1 {
                    windows.removeAll()
                } else {
                    consolePrint("‼️代码漏洞：已经没有sheet了")
                }
                // 使用预先保存的 scene，避免访问可能正在释放的 window
                if let scene = scene {
                    AppContext.sheetWindows[scene] = windows
                }
                
                // 调用回调
                window.windowLevel = .normal
                didDisappearCallback?(self)
                self.navEvents[.onWindowHide]?(self)
                
                // 延迟释放 window，让系统有时间完成内部清理
                // 这可以避免 Mac Catalyst 上 UIWindow 释放时的竞态条件
                DispatchQueue.main.async {
                    // 这个闭包持有 window 的强引用，确保 window 在下一个 RunLoop 才释放
                    _ = window
                }
            }
        } else {
            navEvents[.onViewWillDisappear]?(self)
            window.sheet.translateOut { [weak window, weak self] in
                guard let self = self, let win = window else { return }
                var windows = self.getContextWindows()
                if windows.count > 1 {
                    windows.removeAll { $0 == win }
                } else if windows.count == 1 {
                    windows.removeAll()
                } else {
                    consolePrint("‼️代码漏洞：已经没有sheet了")
                }
                self.setContextWindows(windows)
                win.windowLevel = .normal
                win.sheet.navEvents[.onViewDidDisappear]?(win.sheet)
                win.sheet.navEvents[.onWindowHide]?(win.sheet)
            }
        }
    }
    
    /// 更新HUD实例
    /// - Parameter handler: 实例更新代码
    @objc open func update(handler: @escaping (_ sheet: SheetTarget) -> Void) {
        handler(self)
        reloadData()
        UIView.animateEaseOut(duration: config.animateDurationForReloadByDefault) {
            self.view.layoutIfNeeded()
        }
    }
    
}

extension SheetTarget {
    
    func translateIn(completion: (() -> Void)?) {
        UIView.animateEaseOut(duration: config.animateDurationForBuildInByDefault) {
            self._translateIn()
            if self.config.stackDepthEffect {
                AppContext.updateAppWindowSnapshotIfNeed()
                AppContext.appWindowStackDepthEffect(progress: 0)
                
                ///stackDepthEffect controls the animation effects of the app window.
                ///If set stackDepthEffect, we always enable this feature for the first sheet.
                ///If all sheets are given the ability to control the app window, the animation effects would be pretty bad.
                let allSheets = SheetProvider.findAll()
                if allSheets.count > 0 {
                    var sheetIndex = 0
                    allSheets.forEach({
                        if sheetIndex == 0 {
                            $0.config.stackDepthEffect = true
                        } else {
                            $0.config.stackDepthEffect = false
                        }
                        sheetIndex += 1
                    })
                }
            }
        } completion: { done in
            completion?()
        }
    }
    
    func translateOut(completion: (() -> Void)?) {
        UIView.animateLinear(duration: config.animateDurationForBuildOutByDefault) {
            self._translateOut()
            if self.config.stackDepthEffect {
                AppContext.appWindowStackDepthEffect(progress: 1)
            }
        } completion: { done in
            completion?()
            if self.config.stackDepthEffect {
                AppContext.removeStackDepthEffectSnapshot()
            }
        }
    }
    
    func _translateIn() {
        backgroundView.alpha = 1
        contentView.transform = .identity
    }
    
    func _translateOut() {
        backgroundView.alpha = 0
        contentView.transform = .init(translationX: 0, y: view.frame.size.height - contentView.frame.minY + config.windowEdgeInset)
    }
    
}
