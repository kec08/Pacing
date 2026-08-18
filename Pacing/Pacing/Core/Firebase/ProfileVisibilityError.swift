import Foundation

enum ProfileVisibilityError: LocalizedError {
    case notVisible

    var errorDescription: String? {
        "이 프로필은 현재 공개되지 않았어요."
    }
}
