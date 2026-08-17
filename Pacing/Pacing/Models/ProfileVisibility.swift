import Foundation

enum ProfileVisibility: String, CaseIterable, Identifiable {
    case `public`
    case friendsOnly
    case `private`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .public: "전체 공개"
        case .friendsOnly: "친구만 공개"
        case .private: "비공개"
        }
    }

    var description: String {
        switch self {
        case .public: "로그인한 모든 사용자가 내 프로필을 볼 수 있어요."
        case .friendsOnly: "서로 친구인 사용자만 내 프로필을 볼 수 있어요."
        case .private: "나만 내 프로필을 볼 수 있어요."
        }
    }
}
