import Foundation

struct PhoneRunCommand: Codable, Equatable {
    enum Action: String, Codable {
        case start
        case pause
        case resume
        case finish
    }

    enum Sender: String, Codable {
        case phone
        case watch
    }

    let id: UUID
    let action: Action
    let sender: Sender
    let sessionID: UUID
    let startAt: Date?
    let sentAt: Date

    init(
        action: Action,
        sender: Sender,
        sessionID: UUID,
        startAt: Date? = nil,
        id: UUID = UUID(),
        sentAt: Date = .now
    ) {
        self.id = id
        self.action = action
        self.sender = sender
        self.sessionID = sessionID
        self.startAt = startAt
        self.sentAt = sentAt
    }
}
