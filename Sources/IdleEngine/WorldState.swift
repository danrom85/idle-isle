import Foundation

public struct WorldState: Codable, Equatable, Sendable {
    public enum DayPhase: String, CaseIterable, Codable, Sendable {
        case dawn
        case day
        case sunset
        case night
    }

    public enum Activity: String, CaseIterable, Codable, Sendable {
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

    public enum AmbientEvent: String, CaseIterable, Codable, Sendable {
        case none
        case gullPasses
        case fishJumps
        case coconutFalls
        case crabVisits
        case shootingStar
        case whaleSpout
    }

    public enum Mood: String, Codable, Sendable {
        case content
        case curious
        case hungry
        case tired
        case peaceful
    }

    public struct Fish: Codable, Equatable, Sendable {
        public enum State: String, Codable, Sendable {
            case caught
            case carried
            case cooking
            case cooked
            case eaten
            case stolen
        }

        public var state: State = .caught
        public var cookingProgress: Double = 0
    }

    public struct Memory: Codable, Equatable, Sendable {
        public var totalLivedSeconds: TimeInterval = 0
        public var walkingDistance: Double = 0
        public var fishingSeconds: TimeInterval = 0
        public var campfireSeconds: TimeInterval = 0
        public var palmShadeSeconds: TimeInterval = 0
        public var oceanWatchingSeconds: TimeInterval = 0
        public var fishingTrips: Int = 0
        public var fishCaught: Int = 0
        public var mealsEaten: Int = 0
        public var fishStolenByCrab: Int = 0
        public var nightsSlept: Int = 0
        public var coconutFallsWitnessed: Int = 0
        public var lastRecordedActivity: Activity = .idle

        private enum CodingKeys: String, CodingKey {
            case totalLivedSeconds
            case walkingDistance
            case fishingSeconds
            case campfireSeconds
            case palmShadeSeconds
            case oceanWatchingSeconds
            case fishingTrips
            case fishCaught
            case mealsEaten
            case fishStolenByCrab
            case nightsSlept
            case coconutFallsWitnessed
            case lastRecordedActivity
        }

        public init() {}

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            totalLivedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .totalLivedSeconds) ?? 0
            walkingDistance = try container.decodeIfPresent(Double.self, forKey: .walkingDistance) ?? 0
            fishingSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .fishingSeconds) ?? 0
            campfireSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .campfireSeconds) ?? 0
            palmShadeSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .palmShadeSeconds) ?? 0
            oceanWatchingSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .oceanWatchingSeconds) ?? 0
            fishingTrips = try container.decodeIfPresent(Int.self, forKey: .fishingTrips) ?? 0
            fishCaught = try container.decodeIfPresent(Int.self, forKey: .fishCaught) ?? 0
            mealsEaten = try container.decodeIfPresent(Int.self, forKey: .mealsEaten) ?? 0
            fishStolenByCrab = try container.decodeIfPresent(Int.self, forKey: .fishStolenByCrab) ?? 0
            nightsSlept = try container.decodeIfPresent(Int.self, forKey: .nightsSlept) ?? 0
            coconutFallsWitnessed = try container.decodeIfPresent(Int.self, forKey: .coconutFallsWitnessed) ?? 0
            lastRecordedActivity = try container.decodeIfPresent(Activity.self, forKey: .lastRecordedActivity) ?? .idle
        }

        public var pathWear: Double { min(1, walkingDistance / 2.8) }
        public var fishingSpotWear: Double { min(1, fishingSeconds / 75) }
        public var campfireWear: Double { min(1, campfireSeconds / 80) }
        public var palmShadeWear: Double { min(1, palmShadeSeconds / 90) }
        public var coconutFamiliarity: Double { min(1, Double(coconutFallsWitnessed) / 10) }
        public var rememberedDays: Int { Int(totalLivedSeconds / 200) }
    }

    public var elapsedTime: TimeInterval = 0
    public var simulatedHour: Double = 8
    public var dayPhase: DayPhase = .day

    // Shared island conditions. Every visible system should derive from these.
    public var wind: Double = 0.22
    public var targetWind: Double = 0.22
    public var cloudCover: Double = 0.28
    public var targetCloudCover: Double = 0.28
    public var nextWeatherChangeIn: TimeInterval = 12

    // The ocean completes one gentle tide cycle every 210 real seconds.
    // Phase is normalized to 0...1; level is 0 at low tide and 1 at high tide.
    public var tidePhase: Double = 0.35
    public var tideLevel: Double = 0.90

    // Rainfall intensity, 0 at clear skies and 1 at a steady downpour.
    // Storms arrive only under heavy cloud and fade slowly afterward.
    public var rain: Double = 0
    public var targetRain: Double = 0

    // Castaway state.
    public var activity: Activity = .idle
    public var ambientEvent: AmbientEvent = .none
    public var energy: Double = 0.85
    public var hunger: Double = 0.18
    public var curiosity: Double = 0.45
    public var characterX: Double = 0.45
    /// Position on the island's depth axis: 0 at the back edge, 1 at the
    /// waterline. The island is a real place now, not a tightrope.
    public var characterY: Double = 0.5
    public var destinationX: Double = 0.45
    public var destinationY: Double = 0.5
    public var activityTimeRemaining: TimeInterval = 2
    public var nextAmbientEventIn: TimeInterval = 5

    /// Save format version. Absent in saves from before versioning existed;
    /// persistence upgrades it to `currentSchemaVersion` after a clean load.
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int?

    // Optional preserves compatibility with world saves created before fish existed.
    public var fish: Fish?
    public var memory = Memory()

    public init() {}

    // Field-by-field decoding keeps older world saves loading as the state
    // gains new properties; missing keys fall back to current defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        elapsedTime = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsedTime) ?? 0
        simulatedHour = try container.decodeIfPresent(Double.self, forKey: .simulatedHour) ?? 8
        dayPhase = try container.decodeIfPresent(DayPhase.self, forKey: .dayPhase) ?? .day
        wind = try container.decodeIfPresent(Double.self, forKey: .wind) ?? 0.22
        targetWind = try container.decodeIfPresent(Double.self, forKey: .targetWind) ?? 0.22
        cloudCover = try container.decodeIfPresent(Double.self, forKey: .cloudCover) ?? 0.28
        targetCloudCover = try container.decodeIfPresent(Double.self, forKey: .targetCloudCover) ?? 0.28
        nextWeatherChangeIn = try container.decodeIfPresent(TimeInterval.self, forKey: .nextWeatherChangeIn) ?? 12
        tidePhase = try container.decodeIfPresent(Double.self, forKey: .tidePhase) ?? 0.35
        tideLevel = try container.decodeIfPresent(Double.self, forKey: .tideLevel) ?? 0.90
        rain = try container.decodeIfPresent(Double.self, forKey: .rain) ?? 0
        targetRain = try container.decodeIfPresent(Double.self, forKey: .targetRain) ?? 0
        activity = try container.decodeIfPresent(Activity.self, forKey: .activity) ?? .idle
        ambientEvent = try container.decodeIfPresent(AmbientEvent.self, forKey: .ambientEvent) ?? .none
        energy = try container.decodeIfPresent(Double.self, forKey: .energy) ?? 0.85
        hunger = try container.decodeIfPresent(Double.self, forKey: .hunger) ?? 0.18
        curiosity = try container.decodeIfPresent(Double.self, forKey: .curiosity) ?? 0.45
        characterX = try container.decodeIfPresent(Double.self, forKey: .characterX) ?? 0.45
        characterY = try container.decodeIfPresent(Double.self, forKey: .characterY) ?? 0.5
        destinationX = try container.decodeIfPresent(Double.self, forKey: .destinationX) ?? 0.45
        destinationY = try container.decodeIfPresent(Double.self, forKey: .destinationY) ?? 0.5
        activityTimeRemaining = try container.decodeIfPresent(TimeInterval.self, forKey: .activityTimeRemaining) ?? 2
        nextAmbientEventIn = try container.decodeIfPresent(TimeInterval.self, forKey: .nextAmbientEventIn) ?? 5
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
        fish = try container.decodeIfPresent(Fish.self, forKey: .fish)
        memory = try container.decodeIfPresent(Memory.self, forKey: .memory) ?? Memory()
    }

    private enum CodingKeys: String, CodingKey {
        case elapsedTime
        case simulatedHour
        case dayPhase
        case wind
        case targetWind
        case cloudCover
        case targetCloudCover
        case nextWeatherChangeIn
        case tidePhase
        case tideLevel
        case rain
        case targetRain
        case activity
        case ambientEvent
        case energy
        case hunger
        case curiosity
        case characterX
        case characterY
        case destinationX
        case destinationY
        case activityTimeRemaining
        case nextAmbientEventIn
        case schemaVersion
        case fish
        case memory
    }

    public var mood: Mood {
        if hunger > 0.72 { return .hungry }
        if energy < 0.30 { return .tired }
        if activity == .watchingOcean || activity == .resting { return .peaceful }
        if curiosity > 0.68 { return .curious }
        return .content
    }

    public var debugSummary: String {
        let activityName = activity.rawValue == "watchingOcean" ? "Watching Ocean" : activity.rawValue.capitalized
        return "\(dayPhase.rawValue.capitalized) • \(activityName) • \(mood.rawValue.capitalized) • E \(Int(energy * 100))% • H \(Int(hunger * 100))% • Wind \(Int(wind * 100))% • Rain \(Int(rain * 100))% • Tide \(Int(tideLevel * 100))% • Memory day \(memory.rememberedDays)"
    }
}
