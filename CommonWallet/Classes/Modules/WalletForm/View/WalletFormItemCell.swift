import Foundation

final class WalletFormItemCell: UITableViewCell, WalletFormCellProtocol {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var detailsLabel: UILabel!

    var viewModel: WalletFormViewModelProtocol?

    var style: WalletFormCellStyleProtocol? {
        didSet {
            applyStyle()
        }
    }

    func bind(viewModel: WalletFormViewModelProtocol) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title
        detailsLabel.text = viewModel.details
        iconImageView.image = viewModel.icon

        applyDetailsColor()
    }

    private func applyStyle() {
        if let style = style {
            titleLabel.textColor = style.title.color
            titleLabel.font = style.title.font
            detailsLabel.font = style.details.font
        }

        applyDetailsColor()
    }

    private func applyDetailsColor() {
        if let style = style, let viewModel = viewModel {
            detailsLabel.textColor = viewModel.detailsColor ?? style.details.color
        }
    }

    static func calculateHeight(for viewModel: WalletFormViewModelProtocol,
                                style: WalletFormCellStyleProtocol,
                                preferredWidth: CGFloat) -> CGFloat {
        return 55.0
    }
}
