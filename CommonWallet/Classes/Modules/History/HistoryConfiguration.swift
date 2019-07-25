import Foundation
import SoraUI

protocol HistoryConfigurationProtocol {
    var viewStyle: HistoryViewStyleProtocol { get }
    var cellStyle: TransactionCellStyleProtocol { get }
    var headerStyle: TransactionHeaderStyleProtocol { get }
    var supportsFilter: Bool { get }
    var emptyStateDataSource: EmptyStateDataSource? { get }
    var emptyStateDelegate: EmptyStateDelegate? { get }
}

struct HistoryConfiguration: HistoryConfigurationProtocol {
    var viewStyle: HistoryViewStyleProtocol
    var cellStyle: TransactionCellStyleProtocol
    var headerStyle: TransactionHeaderStyleProtocol
    var supportsFilter: Bool
    var emptyStateDataSource: EmptyStateDataSource?
    weak var emptyStateDelegate: EmptyStateDelegate?
}
