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

    enum Mood: String, Sendable {
        case content
        case curious
        case hungry
        case tired
        case peaceful
    }

    var elapsedTime: TimeInterval = 0
    var simulatedHour: Double = 8
    var dayPhase: DayPhase = .day

    // Shared island conditions. These values should eventually drive every
    // visible system: water, palms, smoke, clouds, wildlife, and sound.
    var wind: Double = 0.22
    var targetWind: Double = 0.22
    var cloudCover: Double = 0.28
    var targetCloudCover: Double = 0.28
    var nextWeatherChangeIn: TimeInterval = 12

    // Castaway state.
    var activity: Activity = .idle
    var ambientEvent: AmbientEvent = .none
    var energy: Double = 0.85
    var hunger: Double = 0.18
    var curiosity: Double = 0.45
    var characterX: Double = 0.45
    var destinationX: Double = 0.45
    var activityTimeRemaining: TimeInterval = 2
    var nextAmbientEventIn: TimeInterval = 5

    var mood: Mood {
        if hunger > 0.72 { return .hungry }
        if energy < 0.30 { return .tired }
        if activity == .watchingOcean || activity == .resting { return .peaceful }
        if curiosity > 0.68 { return .curious }
        return .content
    }

    var debugSummary: String {
        let activityName = activity.rawValue == "watchingOcean" ? "Watching Ocean" : activity.rawValue.capitalized
        return "\(dayPhase.rawValue.capitalized) • \(activityName) • \(mood.rawValue.capitalized) • E \(Int(energy * 100))% • H \(Int(hunger * 100))% • Wind \(Int(wind * 100))%"
    }
}
