import Foundation

struct PhoneRunSnapshot: Codable {
    enum State: String, Codable { case running, paused, ended }
    let state: State
    let elapsedSeconds: Int
    let distanceKilometers: Double
    let paceMinutesPerKilometer: Double
    let sentAt: Date
}
