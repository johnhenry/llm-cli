import Foundation
import FoundationModels

enum ModelSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var systemModel: SystemLanguageModel {
        // For now, all use default since FoundationModels doesn't expose size selection
        return SystemLanguageModel.default
    }
}
