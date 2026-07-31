import Foundation

struct WorldState: Codable, Equatable, Sendable {
    enum DayPhase: String, CaseIterable, Codable, Sendable {
        case dawn
        case day
        case sunset
        case night
    }

    enum Activity: String, CaseIterable, Codable, Sendable {
        case idle
        case walking
        case fishing
        case carryingFish
        case cookingFish
        case eatingFish
        case reactingToCrab
        case resting
        case sleeping
        case watchingOcean
    }

    enum AmbientEvent: String, CaseIterable, Codable, Sendable {
        case none
        case gullPasses
        case fishJumps
        case coconutFalls
        case crabVisits
        case shootingStar
    }

    enum Mood: String, Codable, Sendable {
        case content
        case curious
        case hungry
        case tired
        case peaceful
    }

    struct Fish: Codable, Equatable, Sendable {
        enum State: String, Codable, Sendable {
            case caught
            case carried
            case cooking
            case cooked
            case eaten
            case stolen
        }

        var state: State = .caught
        var cookingProgress: Double = 0
    }

    struct Memory: Codable, Equatable, Sendable {
        var totalLivedSeconds: TimeInterval = 0
        var walkingDistance: Double = 0
        var fishingSeconds: TimeInterval = 0
        var campfireSeconds: TimeInterval = 0
        var palmShadeSeconds: TimeInterval = 0
        var oceanWatchingSeconds: TimeInterval = 0
        var fishingTrips: Int = 0
        var fishCaught: Int = 0
        var mealsEaten: Int = 0
        var fishStolenByCrab: Int = 0
        var nightsSlept: Int = 0
        var coconutFallsWitnessed: Int = 0
        var lastRecordedActivity: Activity = .idle

        var pathWear: Double { min(1, walkingDistance / 2.8) }
        var fishingSpotWear: Double { min(1, fishingSeconds / 75) }
        var campfireWear: Double { min(1, campfireSeconds / 80) }
        var palmShadeWear: Double { min(1, palmShadeSeconds / 90) }
        var coconutFamiliarity: Double { min(1, Double(coconutFallsWitnessed) / 10) }
        var rememberedDays: Int { Int(totalLivedSeconds / 200) }
    }

    var elapsedTime: TimeInterval = 0
    var simulatedHour: Double = 8
    var dayPhase: DayPhase = .day

    // Shared island conditions. Every visible system should derive from these.
    var wind: Double = 0.22
    var targetWind: Double = 0.22
    var cloudCover: Double = 0.28
    var targetCloudCover: Double = 0.28
    var nextWeatherChangeIn: TimeInterval = 12

    // The ocean completes one gentle tide cycle every 210 real seconds.
    // Phase is normalized to 0...1; level is 0 at low tide and 1 at high tide.
    var tidePhase: Double = 0.35
    var tideLevel: Double = 0.90

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

    // Optional preserves compatibility with world saves created before fish existed.
    var fish: Fish?
    var memory = Memory()

    var mood: Mood {
        if hunger > 0.72 { return .hungry }
        if energy < 0.30 { return .tired }
        if activity == .watchingOcean || activity == .resting { return .peaceful }
        if curiosity > 0.68 { return .curious }
        return .content
    }

    var debugSummary: String {
        let activityName = activity.rawValue == "watchingOcean" ? "Watching Ocean" : activity.rawValue.capitalized
        return "\(dayPhase.rawValue.capitalized) • \(activityName) • \(mood.rawValue.capitalized) • E \(Int(energy * 100))% • H \(Int(hunger * 100))% • Wind \(Int(wind * 100))% • Tide \(Int(tideLevel * 100))% • Memory day \(memory.rememberedDays)"
    }
}
