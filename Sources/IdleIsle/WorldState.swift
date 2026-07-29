import Foundation

struct WorldState: Equatable, Sendable {
    enum DayPhase: String, CaseIterable, Sendable {
        case dawn
        case day
        case sunset
        case night
    }

    enum Activity: String, CaseIterable, Sendable {
        case idle
        case walking
        case fishing
        case resting
        case sleeping
        case watchingOcean
    }

    enum AmbientEvent: String, CaseIterable, Sendable {
        case none
        case gullPasses
        case fishJumps
        case coconutFalls
        case crabVisits
        case shootingStar
    }

    var elapsedTime: TimeInterval = 0
    var simulatedHour: Double = 8
    var dayPhase: DayPhase = .day
    var activity: Activity = .idle
    var ambientEvent: AmbientEvent = .none
    var energy: Double = 0.85
    var curiosity: Double = 0.45
    var characterX: Double = 0.45
    var destinationX: Double = 0.45
    var activityTimeRemaining: TimeInterval = 2
    var nextAmbientEventIn: TimeInterval = 5

    var debugSummary: String {
        "\(dayPhase.rawValue.capitalized) • \(activity.rawValue.capitalized) • Energy \(Int(energy * 100))%"
    }
}
