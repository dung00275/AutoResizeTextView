//
//  ViewController.swift
//  InputViewDemo
//
//  Created by Dung Vu on 1/7/19.
//  Copyright © 2019 Dung Vu. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

struct KeyBoardInfor {
    let hidden: Bool
    let height: CGFloat
    let duration: TimeInterval
    
    init?(_ notify: Notification) {
        guard let userInfor = notify.userInfo else {
            return nil
        }
        hidden = notify.name == UIResponder.keyboardWillHideNotification
        height = hidden ? 0 : ((userInfor[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height ?? 0)
        duration = (userInfor[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0
    }
    
    func animate(view: UIView?) {
        let transfrom = CGAffineTransform(translationX: 0, y: -height)
        UIView.animate(withDuration: duration) {
            // Check if it is scrollview --> only change inset else -> transform
            
            guard !(view is UITextView), let scrollView = view as? UIScrollView else {
                view?.transform = transfrom
                return
            }
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.height, right: 0)
        }
    }
}

// MARK: Main Access
protocol DisposeAbleProtocol {
    var disposeBag: DisposeBag { get }
}

protocol ViewAccessProtocol {
    var containerView: UIView? { get }
}

protocol CloseProtocol {
    func close()
}

// MARK: Animate Key Board
protocol AnimateKeyBoardProtocol: AnyObject, DisposeAbleProtocol, ViewAccessProtocol {
    func runAnimate(by keyboarInfor: KeyBoardInfor?)
}

extension AnimateKeyBoardProtocol {
    func runAnimate(by keyboarInfor: KeyBoardInfor?) {
        keyboarInfor?.animate(view: self.containerView)
    }
}

extension AnimateKeyBoardProtocol {//where Self: UIViewController {
    func setupAnimateKeyBoard() {
        let eShowKeyBoard = NotificationCenter.default.rx.notification(UIResponder.keyboardWillShowNotification).map({ KeyBoardInfor($0) })
        let eHideKeyBoard = NotificationCenter.default.rx.notification(UIResponder.keyboardWillHideNotification).map({ KeyBoardInfor($0) })
        
        Observable.merge([eShowKeyBoard, eHideKeyBoard]).bind { [weak self] in
            self?.runAnimate(by: $0)
        }.disposed(by: disposeBag)
    }
}

@IBDesignable
class InputAutoResizeView: UITextView {
    @IBInspectable var placeholderTextColor: UIColor = #colorLiteral(red: 0.8980392157, green: 0.8980392157, blue: 0.8980392157, alpha: 1) {
        didSet {
            setNeedsDisplay()
        }
    }
    @IBInspectable var fade: TimeInterval = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable var placeholder: String? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable var placeholderColor: UIColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    @IBInspectable var maxH: CGFloat = 150
    @IBInspectable var minH: CGFloat = 36.5
    
    var attributedPlaceholder: NSAttributedString? {
        didSet {
            guard let att = self.attributedPlaceholder else {
                return
            }
            self._placeholderTextView.attributedText = att
        }
    }
    
    private (set) lazy var disposeBag: DisposeBag = DisposeBag()
    private lazy var _placeholderTextView: UILabel = {
        let t = UILabel(frame: .zero)
        return t
    }()
    
    override var intrinsicContentSize: CGSize {
        let width = super.intrinsicContentSize.width
        return CGSize(width: width, height: contentSize.height)
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        prepare()
        setupRX()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
        setupRX()
    }
    
    private func setupLayout() {
        self.snp.makeConstraints { (make) in
            make.height.equalTo(minH)
        }
    }
    
    private func prepare() {
        let inset = self.textContainerInset
        self.addSubview(_placeholderTextView)
        self.sendSubviewToBack(_placeholderTextView)
        _placeholderTextView.isUserInteractionEnabled = false
        _placeholderTextView.snp.makeConstraints { (make) in
            make.left.equalTo(inset.left + 2)
            make.top.equalTo(inset.top - 4)
            make.right.equalTo(-inset.right)
        }
        setupLayout()
    }
    
    private func setupPlaceHolder() {
        _placeholderTextView.font = self.font
        _placeholderTextView.textColor = self.placeholderColor
        if let p = placeholder {
            self.attributedPlaceholder = NSAttributedString(string: p)
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        setupPlaceHolder()
    }
    
    private func setupRX() {
        NotificationCenter.default.rx.notification(UITextView.textDidChangeNotification).bind { [weak self](_) in
            self?.updateHeightInput()
        }.disposed(by: disposeBag)
        self.rx.text.map{ !($0?.count == 0) }.bind(to: self._placeholderTextView.rx.isHidden).disposed(by: disposeBag)
    }
    
    private func updateHeightInput() {
        let w = self.frame.width
        let newSize = self.sizeThatFits(CGSize(width: w, height: CGFloat.greatestFiniteMagnitude))
        let padding = self.textContainer.lineFragmentPadding
        var newMax = min(maxH, newSize.height + padding)
        newMax = max(minH, newMax)
        
        self.snp.updateConstraints { (make) in
            make.height.equalTo(newMax)
        }
        UIView.animate(withDuration: 0.0) {
            self.invalidateIntrinsicContentSize()
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }
}


class ViewController: UIViewController, AnimateKeyBoardProtocol {
    var disposeBag: DisposeBag = DisposeBag()
    
    var containerView: UIView? {
        return textView
    }
    
    let textView = InputAutoResizeView(frame: .zero)
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        textView.backgroundColor = .red
        self.view.addSubview(textView)
        
        textView.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        textView.placeholder = "Nhap text"
        setupAnimateKeyBoard()
    }


}

