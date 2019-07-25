import Foundation
import CommonWallet

protocol DemoHeaderViewModelProtocol: WalletViewModelProtocol {
    var title: String { get }
    var style: WalletTextStyleProtocol { get }
    var delegate: DemoHeaderViewModelDelegate? { get }
}

protocol DemoHeaderViewModelDelegate: class {
    func didSelectClose(for viewModel: DemoHeaderViewModelProtocol)
}

final class DemoHeaderViewModel: DemoHeaderViewModelProtocol {
    var cellReuseIdentifier: String = "co.jp.demo.header.identifier"
    var itemHeight: CGFloat = 60.0

    var title: String
    var style: WalletTextStyleProtocol

    weak var delegate: DemoHeaderViewModelDelegate?

    init(title: String, style: WalletTextStyleProtocol) {
        self.title = title
        self.style = style
    }

    func didSelect() {}
}
