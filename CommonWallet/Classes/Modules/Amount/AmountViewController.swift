/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI
import SoraFoundation

final class AmountViewController: AccessoryViewController {
    private struct Constants {
        static let horizontalMargin: CGFloat = 20.0
        static let assetHeight: CGFloat = 54.0
        static let amountHeight: CGFloat = 70.0
        static let shortcutHeight: CGFloat = 54.0
        static let feeHeight: CGFloat = 45.0
        static let toolbarHeight: CGFloat = 40.0
        static let amountInsets = UIEdgeInsets(top: 17.0, left: 0.0, bottom: 8.0, right: 0.0)
        static let feeInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 17.0, right: 0.0)
        static let descriptionInsets = UIEdgeInsets(top: 17.0, left: 0.0, bottom: 8.0, right: 0.0)
        static let shortcutMargin: CGFloat = 10.0
        static let unitPrice: Int = 6250
        static let unitBase: Int = 5000
        static let administratorString: String = "administrator"
    }

    var presenter: AmountPresenterProtocol!

    let containingFactory: ContainingViewFactoryProtocol
    let style: WalletStyleProtocol

    override var accessoryStyle: WalletAccessoryStyleProtocol? {
        style.accessoryStyle
    }

    private var containerView = ScrollableContainerView()

    private var selectedAssetView: SelectedAssetView!
    private var amountInputView: AmountInputView!
    private var feeView: FeeView!
    private var descriptionInputView: DescriptionInputView!
    private var picker: UIPickerView!
    private var pickerList: [Int] = [Int](0...20)
    private var pickerField: UITextField!
    private var feeViewHeight: NSLayoutConstraint!
    private var assetString: String?

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

        configureContentView()

        configureStyle()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func configureContentView() {
        selectedAssetView = containingFactory.createSelectedAssetView()
        selectedAssetView.delegate = self
        selectedAssetView.borderedView.borderType = []
        selectedAssetView.heightAnchor.constraint(equalToConstant: Constants.assetHeight).isActive = true
        selectedAssetView.titleControl.titleLabel.font = selectedAssetView.titleControl.titleLabel.font.withSize(20)

        amountInputView = containingFactory.createAmountInputView(for: .large)
        amountInputView.borderedView.borderType = [.top]
        amountInputView.contentInsets = Constants.amountInsets
        amountInputView.keyboardIndicatorMode = .never
        amountInputView.titleLabel.textColor = style.bodyTextColor
        amountInputView.titleLabel.font = amountInputView.titleLabel.font.withSize(20)
        amountInputView.assetLabel.font = amountInputView.assetLabel.font.withSize(40)
        amountInputView.assetLabel.textColor = .normalLinkColor
        amountInputView.amountField.font = amountInputView.amountField.font?.withSize(40)
        amountInputView.amountField.textColor = .normalLinkColor
        amountInputView.amountField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [NSAttributedString.Key.foregroundColor : UIColor.normalLinkColor])
        let amountHeight = Constants.amountHeight + Constants.amountInsets.top + Constants.amountInsets.bottom
        amountInputView.heightAnchor.constraint(equalToConstant: amountHeight).isActive = true

        feeView = containingFactory.createFeeView()
        feeView.delegate = self
        feeView.contentInsets = Constants.feeInsets
        feeView.borderedView.borderType = [.bottom]
        feeViewHeight = feeView.heightAnchor.constraint(equalToConstant: Constants.feeHeight)
        feeViewHeight.isActive = true

        descriptionInputView = containingFactory.createDescriptionInputView()
        descriptionInputView.contentInsets = Constants.descriptionInsets
        descriptionInputView.keyboardIndicatorMode = .never
        descriptionInputView.borderedView.borderType = []

        let views: [UIView]
        if UserDefaults.standard.bool(forKey: Constants.administratorString) {
            views = [selectedAssetView, createAmountInputShortcut(), amountInputView, feeView]
        } else {
            views = [selectedAssetView, amountInputView, feeView]
        }

        views.forEach {
            containerView.stackView.addArrangedSubview($0)
            $0.widthAnchor.constraint(equalTo: view.widthAnchor,
                                      constant: -2 * Constants.horizontalMargin).isActive = true
        }
    }
    
    private func configureStyle() {
        view.backgroundColor = style.backgroundColor
    }
    
    private func setupLocalization() {
        amountInputView.titleLabel.text = L10n.Amount.send
    }

    private func updateConfirmationState() {
        let isEnabled = (selectedAssetView.viewModel?.isValid ?? false) &&
            (amountInputView.inputViewModel?.isValid ?? false) &&
            (descriptionInputView.viewModel?.isValid ?? false)

        accessoryView?.isActionEnabled = isEnabled
    }

    private func scrollToAmount(animated: Bool) {
        let amountFrame = containerView.scrollView.convert(amountInputView.frame,
                                                           from: containerView.stackView)
        containerView.scrollView.scrollRectToVisible(amountFrame, animated: animated)
    }

    private func scrollToDescription(animated: Bool) {
        if let selectionRange = descriptionInputView.textView.selectedTextRange {
            var caretRectangle = descriptionInputView.textView.caretRect(for: selectionRange.start)
            caretRectangle.origin.x += descriptionInputView.textView.frame.minX
            caretRectangle.origin.y += descriptionInputView.textView.frame.minY

            let scrollFrame = containerView.scrollView.convert(caretRectangle, from: descriptionInputView)
            containerView.scrollView.scrollRectToVisible(scrollFrame, animated: animated)
        }
    }
    
    private func createAmountInputShortcut() -> UIStackView {
        let stackView = UIStackView()
        stackView.backgroundColor = .clear
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = Constants.shortcutMargin
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = L10n.Amount.ticketTitle
        label.textColor = style.bodyTextColor
        label.font = style.bodyRegularFont
        
        pickerField = UITextField()
        pickerField.attributedPlaceholder = NSAttributedString(string: L10n.Amount.ticketNonSelect, attributes: [NSAttributedString.Key.foregroundColor : style.bodyTextColor])

        if let caretColor = style.caretColor {
            pickerField.tintColor = caretColor
        }
        pickerField.font = style.header2Font
        
        picker = UIPickerView()
        picker.delegate = self
        picker.dataSource = self
        
        let toolbar = UIToolbar(frame: CGRect(x: 0.0, y: 0.0, width: view.frame.size.width, height: Constants.toolbarHeight))
        let spaceItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        toolbar.setItems([spaceItem, doneItem], animated: true)
        
        pickerField.inputView = picker
        pickerField.inputAccessoryView = toolbar
        
        let spacerView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0))
        
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(pickerField)
        stackView.addArrangedSubview(spacerView)
        
        pickerField.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        
        return stackView
    }

    // MARK: Override Superclass

    override func updateBottom(inset: CGFloat) {
        super.updateBottom(inset: inset)

        var currentInsets = containerView.scrollView.contentInset
        currentInsets.bottom = inset

        containerView.scrollView.contentInset = currentInsets

        view.layoutIfNeeded()

        if amountInputView.amountField.isFirstResponder {
            scrollToAmount(animated: false)
        }

        if descriptionInputView.textView.isFirstResponder {
            scrollToDescription(animated: false)
        }
    }

    @objc override func actionAccessory() {
        super.actionAccessory()

        amountInputView.amountField.resignFirstResponder()
        descriptionInputView.textView.resignFirstResponder()

        presenter.confirm()
    }
    
    // MARK: Actions
    
    @objc func done() {
        pickerField.endEditing(true)
        for _ in 0...amountInputView.inputViewModel!.displayAmount.count {
            amountInputView.inputViewModel?.didReceiveReplacement("", for: NSRange(location: 0, length: 1))
        }
        let amount = pickerList[picker.selectedRow(inComponent: 0)] * Constants.unitPrice
        if amount > 0 {
            amountInputView.inputViewModel?.didReceiveReplacement("\(amount)", for: NSRange(location: 0, length: "\(amount)".count))
        }
    }
}


extension AmountViewController: AmountViewProtocol {
    func set(title: String) {
        self.title = title
    }

    func set(assetViewModel: AssetSelectionViewModelProtocol) {
        selectedAssetView.viewModel?.observable.remove(observer: self)

        assetViewModel.observable.add(observer: self)

        selectedAssetView.bind(viewModel: assetViewModel)
        amountInputView.bind(assetSelectionViewModel: assetViewModel)

        updateConfirmationState()
    }

    func set(amountViewModel: AmountInputViewModelProtocol) {
        self.amountInputView.inputViewModel?.observable.remove(observer: self)

        amountViewModel.observable.add(observer: self)

        amountInputView.bind(inputViewModel: amountViewModel)

        updateConfirmationState()
    }

    func set(descriptionViewModel: DescriptionInputViewModelProtocol) {
        descriptionInputView.viewModel?.observable.remove(observer: self)
        descriptionViewModel.observable.add(observer: self)

        descriptionInputView.bind(viewModel: descriptionViewModel)

        updateConfirmationState()
    }

    func set(accessoryViewModel: AccessoryViewModelProtocol) {
        accessoryView?.bind(viewModel: accessoryViewModel)
    }

    func set(feeViewModel: FeeViewModelProtocol) {
        feeView.bind(viewModel: feeViewModel)
    }
}

extension AmountViewController: SelectedAssetViewDelegate {
    func selectedAssetViewDidChange(_ view: SelectedAssetView) {
        if view.activated {
            presenter.presentAssetSelection()
        }
    }
}

extension AmountViewController: AssetSelectionViewModelObserver {
    func assetSelectionDidChangeTitle() {
        updateConfirmationState()
    }

    func assetSelectionDidChangeSymbol() {}

    func assetSelectionDidChangeState() {}
}

extension AmountViewController: AmountInputViewModelObserver {
    func amountInputDidChange() {
        updateConfirmationState()
        if UserDefaults.standard.bool(forKey: Constants.administratorString) {
            if amountInputView.amountField.isFirstResponder {
                self.pickerField.text = ""
            }
        }
    }
}

extension AmountViewController: DescriptionInputViewModelObserver {
    func descriptionInputDidChangeText() {
        updateConfirmationState()
    }
}

extension AmountViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension AmountViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerList.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let symbol: String = selectedAssetView.viewModel?.symbol ?? ""
        
        if pickerList[row] < 1 {
            return L10n.Amount.ticketNonSelect
        }
        let price = amountInputView.inputViewModel?.getFormattedAmount(amount: Decimal(pickerList[row] * Constants.unitPrice))
        let base = amountInputView.inputViewModel?.getFormattedAmount(amount: Decimal(pickerList[row] * Constants.unitBase))
        return L10n.Amount.ticketSelectable(pickerList[row].description, symbol, price!, base!)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row > 0 {
            self.pickerField.text = L10n.Amount.ticketNumberOf(pickerList[row].description)
            amountInputView.amountField.text = amountInputView.inputViewModel?.getFormattedAmount(amount: Decimal(pickerList[row] * Constants.unitPrice))
        } else {
            self.pickerField.text = ""
            amountInputView.amountField.text = ""
        }
    }
}

extension AmountViewController: FeeViewDelegate {
    func feeViewDidChange(_ view: FeeView) {
        if feeView.viewModel!.isHidden {
            feeView.titleLabel.isHidden = true
            feeViewHeight.constant = 0.0
        } else {
            feeView.titleLabel.isHidden = false
            feeViewHeight.constant = Constants.feeHeight
        }
    }
}
