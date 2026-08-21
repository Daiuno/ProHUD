//
//  SheetConvenienceLayout.swift
//  
//
//  Created by xaoxuu on 2022/9/8.
//

import UIKit

extension SheetTarget: ConvenienceLayout {
    
    // MARK: 增加
    @discardableResult public func add(action: Action) -> Button {
        insert(action: action, at: contentStack.arrangedSubviews.count)
    }
    @discardableResult public func insert(action: Action, at index: Int) -> Button {
        let btn = SheetButton(config: config, action: action)
        if index < contentStack.arrangedSubviews.count {
            contentStack.insertArrangedSubview(btn, at: index)
        } else {
            contentStack.addArrangedSubview(btn)
        }
        addTouchUpAction(for: btn) { [weak self] in
            if let self = self {
                action.handler?(self)
            }
            if action.handler == nil {
                self?.pop()
            }
        }
        if isViewAppeared {
            self.contentStack.layoutIfNeeded()
            UIView.animateEaseOut(duration: config.animateDurationForReloadByDefault) {
                self.view.layoutIfNeeded()
            }
        }
        return btn
    }
    
    // MARK: 查找
    public func button(for identifier: String) -> Button? {
        if let index = actionIndex(for: identifier) {
            return contentStack.arrangedSubviews[index] as? Button
        }
        return nil
    }
    
    // MARK: 更新
    public func update(action title: String, style: Action.Style? = nil, for identifier: String) {
        if let btn = button(for: identifier), let act = btn.action {
            act.title = title
            if let style = style {
                act.style = style
            }
            btn.update(config: config, action: act)
        }
    }
    
    // MARK: 删除
    public func remove(actions finder: Action.Filter) {
        if finder.ids.count > 0 {
            for identifier in finder.ids {
                while let index = actionIndex(for: identifier), index < contentStack.arrangedSubviews.count {
                    let view = contentStack.arrangedSubviews[index]
                    contentStack.removeArrangedSubview(view)
                    view.removeFromSuperview()
                    buttonEvents[view] = nil
                }
            }
        } else {
            for view in contentStack.arrangedSubviews {
                contentStack.removeArrangedSubview(view)
                view.removeFromSuperview()
                buttonEvents[view] = nil
            }
        }
        if isViewAppeared {
            UIView.animateEaseOut(duration: config.animateDurationForReloadByDefault) {
                self.contentStack.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
        }
    }
    
    // MARK: 自定义控件
    
    @discardableResult public func add(subview: UIView) -> UIView {
        contentStack.addArrangedSubview(subview)
        return subview
    }
    
    
    // MARK: 布局工具
    
    public func set(spacing: CGFloat, after: UIView?, in stack: UIStackView) {
        if #available(iOS 11.0, *) {
            if let after = after ?? stack.arrangedSubviews.last {
                stack.setCustomSpacing(spacing, after: after)
            }
        }
    }
    
    public func add(spacing: CGFloat) {
        set(spacing: spacing, after: nil, in: contentStack)
    }
    
    // MARK: 完全自定义布局
    @discardableResult public func set(customView: UIView) -> UIView {
        self.customView = customView
        if config.enableCustomViewPanGesture {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCustomViewPanGesture))
            pan.delegate = self
            // 避免下拉 dismiss pan 取消 UITextView 长按/选区触摸，导致复制菜单出不来
            pan.cancelsTouchesInView = false
            customView.addGestureRecognizer(pan)
        }
        contentView.addSubview(customView)
        return customView
    }
    
    @objc func handleCustomViewPanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let customView else { return }
    
        let point = gesture.translation(in: gesture.view)
        if point.y <= 0 {
            //The rubber band animation when pulling up
            let threshold: CGFloat = 0
            let maxTranslation: CGFloat = -35
            let rubberRange = threshold - maxTranslation
            let excess = threshold - point.y
            let decay: CGFloat = 100
            let additional = rubberRange * (1 - exp(-excess / decay))
            contentView.transform = .init(translationX: 0, y: threshold - additional)
            if gesture.state == .recognized {
                UIView.animate(withDuration: 0.5,
                               delay: 0,
                               usingSpringWithDamping: 0.8,
                               initialSpringVelocity: 0,
                               options: [.allowUserInteraction, .curveEaseInOut],
                               animations: {
                    self.contentView.transform = .identity
                })
            }
        } else {
            customView.transform = .init(translationX: 0, y: point.y)
            
            //Simulating iOS window animations
            if config.stackDepthEffect {
                AppContext.appWindowStackDepthEffect(progress: customView.frame.origin.y/(customView.frame.height))
            }
            
            if gesture.state == .recognized {
                let v = gesture.velocity(in: gesture.view)
                if (customView.frame.origin.y > customView.frame.height*2/3 && v.y > 0) || v.y > 1200 {
                    pop()
                } else {
                    UIView.animate(withDuration: 0.5,
                                   delay: 0,
                                   usingSpringWithDamping: 0.8,
                                   initialSpringVelocity: 0,
                                   options: [.allowUserInteraction, .curveEaseInOut],
                                   animations: {
                        customView.transform = .identity
                        
                        if self.config.stackDepthEffect {
                            AppContext.appWindowStackDepthEffect(progress: 0)
                        }
                    })
                }
            }
        }
    }
    
    // MARK: internal
    func actionIndex(for identifier: String) -> Int? {
        let arr = contentStack.arrangedSubviews.compactMap({ $0 as? Button })
        for i in 0 ..< arr.count {
            if arr[i].action?.identifier == identifier {
                return i
            }
        }
        return nil
    }
    
}

extension SheetTarget: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let gesture = gestureRecognizer as? UIPanGestureRecognizer {
            if let panGestureShouldBegin = config.panGestureShouldBegin {
                return panGestureShouldBegin(gesture)
            }
        }
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // shouldReceive 阶段 gesture.location 不可靠，用 touch.view 判断文本控件
        guard gestureRecognizer is UIPanGestureRecognizer,
              config.panGestureShouldBegin != nil else {
            return true
        }
        var view: UIView? = touch.view
        while let current = view {
            if current is UITextView || current is UITextField {
                return false
            }
            view = current.superview
        }
        return true
    }
}

// MARK: more
public extension SheetTarget {
    
    /// 增加一个标题
    /// - Parameter text: 文本
    @discardableResult func add(title text: String?) -> UILabel {
        let lb = add(subTitle: text)
        lb.font = .boldSystemFont(ofSize: 24)
        lb.textColor = config.primaryLabelColor
        lb.textAlignment = .center
        config.customTitleLabel?(lb)
        return lb
    }
    
    /// 增加一个副标题
    /// - Parameter text: 文本
    @discardableResult func add(subTitle text: String?) -> UILabel {
        let lb = UILabel()
        lb.font = .boldSystemFont(ofSize: 20)
        lb.textColor = config.primaryLabelColor
        lb.numberOfLines = 0
        lb.textAlignment = .justified
        config.customSubtitleLabel?(lb)
        lb.text = text
        contentStack.addArrangedSubview(lb)
        if #available(iOS 11.0, *) {
            let count = contentStack.arrangedSubviews.count
            if count > 0 {
                contentStack.setCustomSpacing(12, after: contentStack.arrangedSubviews[count-1])
            }
            if count > 1 {
                contentStack.setCustomSpacing(16, after: contentStack.arrangedSubviews[count-2])
            }
        } else {
            // Fallback on earlier versions
        }
        return lb
    }
    
    /// 增加一段正文
    /// - Parameter text: 文本
    @discardableResult func add(message text: String?) -> UILabel {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 16)
        lb.textColor = config.primaryLabelColor
        lb.numberOfLines = 0
        lb.textAlignment = .justified
        config.customTitleLabel?(lb)
        lb.text = text
        contentStack.addArrangedSubview(lb)
        return lb
    }
    
    /// 增加一个按钮
    /// - Parameters:
    ///   - title: 标题
    ///   - style: 样式
    ///   - identifier: 唯一标识符
    ///   - handler: 点击事件
    /// - Returns: 按钮实例
    @discardableResult func add(action title: String, style: Action.Style = .tinted, identifier: String? = nil, handler: ((_ sheet: SheetTarget) -> Void)? = nil) -> Button {
        if let handler = handler {
            let action = Action(identifier: identifier, style: style, title: title) { vc in
                if let vc = vc as? SheetTarget {
                    handler(vc)
                }
            }
            return add(action: action)
        } else {
            return add(action: .init(identifier: identifier, style: style, title: title, handler: nil))
        }
    }
    
    
}
