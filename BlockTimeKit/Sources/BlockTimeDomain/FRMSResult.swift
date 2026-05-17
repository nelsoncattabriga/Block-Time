import Foundation

/// Output of a complete FRMS compliance calculation (D-05).
/// Pure value type — no persistence coupling.
public struct FRMSResult: Sendable {
    public let cumulativeTotals: FRMSCumulativeTotals
    public let complianceStatus: FRMSComplianceStatus
    public let maximumNextDuty: FRMSMaximumNextDuty?

    public init(cumulativeTotals: FRMSCumulativeTotals,
                complianceStatus: FRMSComplianceStatus,
                maximumNextDuty: FRMSMaximumNextDuty?) {
        self.cumulativeTotals = cumulativeTotals
        self.complianceStatus = complianceStatus
        self.maximumNextDuty = maximumNextDuty
    }
}
