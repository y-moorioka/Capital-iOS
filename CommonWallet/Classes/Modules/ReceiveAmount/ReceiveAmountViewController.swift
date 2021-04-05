/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI
import SoraFoundation


final class ReceiveAmountViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let horizontalMargin: CGFloat = 20.0
        static let verticalSpacing: CGFloat = 17.0
        static let bottomMargin: CGFloat = 8.0
        static let collapsedQrMargin: CGFloat = 6.0
        static let collapsedQrBackgroundHeight: CGFloat = 0.0
        static let expandedQrMargin: CGFloat = 10.0
        static let expandedQrBackgroundHeight: CGFloat = 351.0
        static let assetViewHeight: CGFloat = 54.0
        static let amountViewHeight: CGFloat = 54.0
        static let separatorHeight: CGFloat = 1.0
        static let expandedAdaptiveScaleWhenDecreased: CGFloat = 0.9
        static let inputButtonHeight: CGFloat = 33.0
        static let inputButtonMargin: CGFloat = 5.0
    }

    enum LayoutState {
        case collapsed
        case expanded
    }

    var presenter: ReceiveAmountPresenterProtocol!

    let containingFactory: ContainingViewFactoryProtocol

    let style: WalletStyleProtocol

    var localizableTitle: LocalizableResource<String>?

    private(set) var layoutState: LayoutState = .expanded {
        didSet {
            if layoutState != oldValue {
                updateLayoutConstraints(for: layoutState)
            }
        }
    }

    private var containerView = ScrollableContainerView()

    private var qrView: QRView!
    private var selectedAssetView: SelectedAssetView!
    private var amountInputView: AmountInputView!
    private var descriptionInputView: DescriptionInputView?
    private var doneBuuttonView: UIView?
    private var inputButtonHeight: NSLayoutConstraint!

    private var qrHeight: NSLayoutConstraint!
    private var amountHeight: NSLayoutConstraint!

    private var keyboardHandler: KeyboardHandler?

    init(containingFactory: ContainingViewFactoryProtocol, style: WalletStyleProtocol) {
        self.containingFactory = containingFactory
        self.style = style

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = containerView

        configureNavigationItems()
        configureContentView()

        adjustLayout()
        applyStyle()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        let qrHeight = calculateQrBackgrounHeight(for: .expanded)
        let qrMargin = calculateQrMargin(for: .expanded)
        presenter.setup(qrSize: CGSize(width: qrHeight - 2 * qrMargin, height: qrHeight - 2 * qrMargin))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func configureContentView() {
        qrView = containingFactory.createQrView()
        qrView.margin = Constants.expandedQrMargin
        qrView.borderedView.borderType = []

        qrHeight = qrView.heightAnchor.constraint(equalToConstant: Constants.expandedQrBackgroundHeight)
        qrHeight?.isActive = true

        selectedAssetView = containingFactory.createSelectedAssetView()
        selectedAssetView.borderedView.borderType = []
        selectedAssetView.delegate = self
        selectedAssetView.heightAnchor.constraint(equalToConstant: Constants.assetViewHeight).isActive = true

        amountInputView = containingFactory.createAmountInputView(for: .small)
        amountInputView.titleLabel.text = L10n.Amount.receive
        amountInputView.borderedView.borderType = [.top]
        amountInputView.contentInsets = UIEdgeInsets(top: Constants.verticalSpacing, left: 0.0,
                                                     bottom: Constants.bottomMargin, right: 0.0)
        amountInputView.keyboardIndicatorMode = .always

        let amountHeightValue = Constants.amountViewHeight + Constants.verticalSpacing + Constants.bottomMargin
        amountHeight = amountInputView.heightAnchor
            .constraint(equalToConstant: amountHeightValue)
        amountHeight.isActive = true

        let views: [UIView] = [qrView, createInputButtonView(), createSeparatorView(), selectedAssetView, amountInputView]

        views.forEach { containerView.stackView.addArrangedSubview($0) }

        views[0...2].forEach {
            $0.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        }

        views[3...].forEach {
            $0.widthAnchor.constraint(equalTo: view.widthAnchor,
                                      constant: -2 * Constants.horizontalMargin).isActive = true
        }
    }

    private func configureNavigationItems() {
        let shareItem = UIBarButtonItem(image: style.shareIcon,
                                        style: .plain,
                                        target: self,
                                        action: #selector(actionShare))

        navigationItem.rightBarButtonItem = shareItem
    }

    private func createSeparatorView() -> BorderedContainerView {
        let separatorView = containingFactory.createSeparatorView()
        separatorView.strokeWidth = Constants.separatorHeight
        separatorView.borderType = [.top]

        separatorView.heightAnchor.constraint(equalToConstant: Constants.separatorHeight).isActive = true

        return separatorView
    }
    
    private func createInputButtonView() -> UIStackView {
        let inputButtonView = containingFactory.createDoneButtonView()
        inputButtonView.contentInsets = UIEdgeInsets(top: Constants.bottomMargin, left: Constants.horizontalMargin,
                                                bottom: Constants.bottomMargin, right: Constants.horizontalMargin)
        inputButtonView.imageWithTitleView?.title = L10n.Common.inputAmount(L10n.Amount.receive)
        inputButtonView.addTarget(self, action: #selector(inputButtonTapped), for: .touchUpInside)
        inputButtonHeight = inputButtonView.heightAnchor.constraint(equalToConstant: Constants.inputButtonHeight)
        inputButtonHeight.isActive = true
        
        let stackView = UIStackView()
        stackView.backgroundColor = .white
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = Constants.inputButtonMargin
        
        let spacerView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0))
        stackView.addArrangedSubview(spacerView)
        stackView.addArrangedSubview(inputButtonView)
        stackView.addArrangedSubview(spacerView)
        
        return stackView
    }

    private func addDescriptionView() {
        amountInputView.contentInsets = UIEdgeInsets(top: Constants.verticalSpacing, left: 0.0,
                                                     bottom: Constants.verticalSpacing, right: 0.0)
        amountHeight.constant = 2 * Constants.verticalSpacing + Constants.amountViewHeight
        amountInputView.keyboardIndicatorMode = .never

        let descriptionView = containingFactory.createDescriptionInputView()
        descriptionView.contentInsets = UIEdgeInsets(top: Constants.verticalSpacing, left: 0.0,
                                                     bottom: Constants.bottomMargin, right: 0.0)
        descriptionView.borderedView.borderType = [.top]
        descriptionView.keyboardIndicatorMode = .never

//        containerView.stackView.addArrangedSubview(descriptionView)
//
//        descriptionView.widthAnchor.constraint(equalTo: view.widthAnchor,
//                                               constant: -2 * Constants.horizontalMargin).isActive = true

        self.descriptionInputView = descriptionView
    }
    
    private func addDoneButtonView() {
        let doneButton = containingFactory.createDoneButtonView()
        doneButton.contentInsets = UIEdgeInsets(top: Constants.bottomMargin, left: Constants.horizontalMargin,
                                                bottom: Constants.bottomMargin, right: Constants.horizontalMargin)
        doneButton.imageWithTitleView?.title = L10n.Common.displayQrCode
        doneButton.isEnabled = false
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        switchDisplay(view: doneButton, active: false)
        
        containerView.stackView.addArrangedSubview(doneButton)
        
        self.doneBuuttonView = doneButton
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        if let localizableTitle = localizableTitle {
            title = localizableTitle.value(for: locale)
        }

        amountInputView?.titleLabel.text = L10n.Amount.receive
    }

    private func adjustLayout() {
        updateLayoutConstraints(for: layoutState)
    }

    private func applyStyle() {
        view.backgroundColor = style.backgroundColor
    }

    private func updateLayoutConstraints(for state: LayoutState) {
        qrView?.margin = calculateQrMargin(for: state)
        qrHeight?.constant = calculateQrBackgrounHeight(for: state)
        inputButtonHeight?.constant = getInputButtonHeight(for: state)
    }

    private func calculateQrMargin(for state: LayoutState) -> CGFloat {
        var qrMargin: CGFloat

        switch state {
        case .collapsed:
            qrMargin = Constants.collapsedQrMargin
        case .expanded:
            qrMargin = Constants.expandedQrMargin

            if isAdaptiveWidthDecreased {
                qrMargin *= Constants.expandedAdaptiveScaleWhenDecreased
            }
        }

        qrMargin *= designScaleRatio.width

        return qrMargin
    }

    private func calculateQrBackgrounHeight(for state: LayoutState) -> CGFloat {
        var qrBackgroundHeight: CGFloat

        switch state {
        case .collapsed:
            if let view = containerView.stackView.subviews.last as? RoundedButton {
                switchDisplay(view: view, active: true)
            }
            qrBackgroundHeight = Constants.collapsedQrBackgroundHeight
        case .expanded:
            qrBackgroundHeight = Constants.expandedQrBackgroundHeight

            if isAdaptiveWidthDecreased {
                qrBackgroundHeight *= Constants.expandedAdaptiveScaleWhenDecreased
            }
            
            if let view = containerView.stackView.subviews.last as? RoundedButton {
                switchDisplay(view: view, active: false)
            }
        }

        qrBackgroundHeight *= designScaleRatio.width

        return qrBackgroundHeight
    }
    
    func getInputButtonHeight(for state: LayoutState) -> CGFloat {
        var inputButtonHeight: CGFloat
        switch state {
        case .collapsed:
            inputButtonHeight = .zero
        case .expanded:
            inputButtonHeight = Constants.inputButtonHeight
        }
        
        return inputButtonHeight
    }
    
    private func switchDisplay(view: RoundedButton, active: Bool) {
        view.isEnabled = active
        view.imageWithTitleView?.isHidden = active ? false : true
        view.backgroundView?.isHidden = active ? false : true
    }

    // MARK: Keyboard Handling

    private func setupKeyboardHandler() {
        keyboardHandler = KeyboardHandler()
        keyboardHandler?.animateOnFrameChange = animateKeyboardBoundsChange(for:)
    }

    private func clearKeyboardHandler() {
        keyboardHandler = nil
    }

    private func animateKeyboardBoundsChange(for keyboardFrame: CGRect) {
        let localKeyboardFrame = view.convert(keyboardFrame, from: nil)
        containerView.scrollBottomOffset = max(view.bounds.maxY - localKeyboardFrame.minY, 0.0)

        if containerView.scrollBottomOffset > 0.0 {
            layoutState = .collapsed
        } else {
            layoutState = .expanded
        }

        view.layoutIfNeeded()

        if containerView.scrollBottomOffset > 0.0 {
            scrollToFirstReponder(for: localKeyboardFrame)
        } else {
            scrollToQrCode()
        }
    }

    private func scrollToFirstReponder(for localKeyboardFrame: CGRect) {
        let currentInputView: UIView

        if let descriptionView = descriptionInputView, descriptionView.textView.isFirstResponder {
            currentInputView = descriptionView
        } else {
            currentInputView = amountInputView
        }

        let scrollHeight = view.bounds.maxY - containerView.scrollView.frame.minY -
            containerView.scrollBottomOffset
        let currentInputFrame = containerView.scrollView.convert(currentInputView.frame,
                                                                 from: containerView.stackView)

        if containerView.scrollView.contentOffset.y + scrollHeight < currentInputFrame.maxY {
            let contentOffset = CGPoint(x: 0.0, y: currentInputFrame.maxY - scrollHeight)
            containerView.scrollView.contentOffset = contentOffset
        }
    }

    private func scrollToQrCode() {
        containerView.scrollView.contentOffset = .zero
    }

    // MARK: Action

    @objc private func actionShare() {
        presenter.share()
    }
    
    @objc private func doneButtonTapped() {
        containerView.endEditing(true)
    }
}


extension ReceiveAmountViewController: ReceiveAmountViewProtocol {
    func didReceive(image: UIImage) {
        qrView.imageView.image = image
    }

    func didReceive(assetSelectionViewModel: AssetSelectionViewModelProtocol) {
        selectedAssetView.bind(viewModel: assetSelectionViewModel)
        amountInputView.bind(assetSelectionViewModel: assetSelectionViewModel)
    }

    func didReceive(amountInputViewModel: AmountInputViewModelProtocol) {
        amountInputView.bind(inputViewModel: amountInputViewModel)
    }

    func didReceive(descriptionViewModel: DescriptionInputViewModelProtocol) {
        if descriptionInputView == nil {
            addDescriptionView()
        }
        
        if doneBuuttonView == nil {
            addDoneButtonView()
        }

        descriptionInputView?.bind(viewModel: descriptionViewModel)
    }
}

extension ReceiveAmountViewController: SelectedAssetViewDelegate {
    func selectedAssetViewDidChange(_ view: SelectedAssetView) {
        if view.activated {
            presenter.presentAssetSelection()
        }
    }
}

extension ReceiveAmountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
