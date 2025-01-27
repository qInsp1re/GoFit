
import WidgetKit
import SwiftUI
import HealthKit

class HealthKitManager: ObservableObject {
    private var healthStore: HKHealthStore?

    init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard let healthStore = self.healthStore else {
            completion(false)
            return
        }

        let allTypes = Set([
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ])

        healthStore.requestAuthorization(toShare: [], read: allTypes) { (success, error) in
            completion(success)
        }
    }

    func fetchSteps(completion: @escaping (Double) -> Void) {
        fetchData(for: .stepCount, unit: HKUnit.count(), completion: completion)
    }

    func fetchActiveEnergy(completion: @escaping (Double) -> Void) {
        fetchData(for: .activeEnergyBurned, unit: HKUnit.kilocalorie(), completion: completion)
    }

    func fetchSleepAnalysis(completion: @escaping (Double) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 0, sortDescriptors: nil) { _, samples, _ in
            guard let sleepSamples = samples as? [HKCategorySample] else {
                completion(0.0)
                return
            }
            var totalSleep = 0.0
            for sleepSample in sleepSamples {
                let sleepAmount = sleepSample.endDate.timeIntervalSince(sleepSample.startDate)
                totalSleep += sleepAmount
            }
            completion(totalSleep / 3600) // Convert seconds to hours
        }

        healthStore?.execute(query)
    }

    func fetchAverageHeartRate(completion: @escaping (Double) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(0.0)
            return
        }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
            guard let result = result, let average = result.averageQuantity() else {
                completion(0.0)
                return
            }
            completion(average.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
        }
        
        healthStore?.execute(query)
    }

    func fetchExerciseMinutes(completion: @escaping (Double) -> Void) {
        fetchData(for: .appleExerciseTime, unit: HKUnit.minute(), completion: completion)
    }

    func fetchWeight(completion: @escaping (Double) -> Void) {
        let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample], let lastSample = samples.first else {
                completion(0.0)
                return
            }
            completion(lastSample.quantity.doubleValue(for: HKUnit.gram().unitDivided(by: .gram())))
        }
        
        healthStore?.execute(query)
    }

    enum AuthorizationStatus {
        case authorized
        case notAuthorized
    }
    func getRequestStatusForAuthorization(completion: @escaping (AuthorizationStatus) -> Void) {
        guard let healthStore = self.healthStore else {
            completion(.notAuthorized)
            return
        }

        let allTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!
        ]

        for type in allTypes {
            if healthStore.authorizationStatus(for: type) == .notDetermined {
                completion(.notAuthorized)
                return
            }
        }
        completion(.authorized)
    }


    private func fetchData(for typeIdentifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        let type = HKObjectType.quantityType(forIdentifier: typeIdentifier)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: unit))
        }

        healthStore?.execute(query)
    }
}

struct Provider: TimelineProvider {
    let healthManager = HealthKitManager()
    
    func placeholder(in context: Context) -> HealthEntry {
        return HealthEntry(date: Date(), stepCount: 0, heartRate: 0, activeEnergy: 0, exerciseMinutes: 0, sleepHours: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> ()) {
        getTimeline(in: context) { timeline in
            if let entry = timeline.entries.first {
                completion(entry)
            } else {
                let placeholderEntry = HealthEntry(date: Date(), stepCount: 0, heartRate: 0, activeEnergy: 0, exerciseMinutes: 0, sleepHours: 0)
                completion(placeholderEntry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthEntry>) -> ()) {
        healthManager.getRequestStatusForAuthorization { status in
            switch status {
            case .authorized:
                healthManager.fetchSteps { stepCount in
                    self.healthManager.fetchAverageHeartRate { heartRate in
                        self.healthManager.fetchActiveEnergy { activeEnergy in
                            self.healthManager.fetchExerciseMinutes { exerciseMinutes in
                                self.healthManager.fetchSleepAnalysis { sleepHours in
                                    let entry = HealthEntry(date: Date(), stepCount: stepCount, heartRate: heartRate, activeEnergy: activeEnergy, exerciseMinutes: exerciseMinutes, sleepHours: sleepHours)
                                    let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
                                    let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                                    
                                    completion(timeline)
                                }
                            }
                        }
                    }
                }
            default:
                let entry = HealthEntry(date: Date(), stepCount: 0, heartRate: 0, activeEnergy: 0, exerciseMinutes: 0, sleepHours: 0)
                let timeline = Timeline(entries: [entry], policy: .atEnd)
                completion(timeline)
            }
        }
    }
}

struct HealthEntry: TimelineEntry {
    let date: Date
    let stepCount: Double
    let heartRate: Double
    let activeEnergy: Double
    let exerciseMinutes: Double
    let sleepHours: Double
}

struct CircleProgressView: View {
    var value: Double
    var goal: Double = 100.0
    var title: String

    var body: some View {
        VStack {
            Text(title)
            ZStack {
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(self.value / goal, 1.0)))
                    .stroke(Color.green, lineWidth: 5)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear)
                Circle()
                    .trim(from: 0.0, to: 1.0)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 5)
            }
            .frame(width: 50, height: 50)
            Text("\(Int(self.value))")
        }
    }
}

struct WidgetHealthEntryView: View {
    var entry: Provider.Entry

    var body: some View {
            VStack(spacing: 20) {
                HStack {
                    Text("Доброе утро!")  // Добавляем надпись вверху
                        .font(.title)
                        .fontWeight(.bold)
                        .offset(x: -5, y: -10) // Сдвигаем текст влево и вверх

                    Spacer()
                }
                .padding(.bottom, 10)

                HStack(spacing: 20) {
                    makeMetricView(value: entry.activeEnergy, goal: 300, unit: "Kcal", color: Color.green.opacity(0.7))
                    makeMetricView(value: entry.exerciseMinutes, goal: 30, unit: "min",  color: Color.orange.opacity(0.7))
                    makeMetricView(value: entry.stepCount, goal: 10000, unit: "Steps", color: Color.blue.opacity(0.7))
                }

                Divider()

                HStack(spacing: 20) {
                    makeIconMetricView(icon: "bed.double.fill", value: entry.sleepHours, unit: "Hours", color: Color.purple.opacity(0.7))
                    makeIconMetricView(icon: "heart.fill", value: entry.heartRate, unit: "bpm", color: Color.red.opacity(0.7))
                }
            }
            .padding()
            .containerBackground(.white, for: .widget)
        }

    func makeMetricView(value: Double, goal: Double, unit: String, title: String? = nil, color: Color) -> some View {
        VStack {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            ZStack {
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(value / goal, 1.0)))
                    .stroke(color, lineWidth: 6)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear)
                
                Circle()
                    .trim(from: 0.0, to: 1.0)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 6)
                    .rotationEffect(Angle(degrees: 270.0))

                VStack {
                    Text("\(Int(value))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 80, height: 80)
        }
    }

    func makeIconMetricView(icon: String, value: Double, unit: String, color: Color) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(color)
            
            VStack {
                Text("\(Int(value))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 80, height: 80)
    }
}






struct WidgetHealth: Widget {
    let kind: String = "WidgetHealth"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetHealthEntryView(entry: entry)
        }
        .configurationDisplayName("Health Widget")
        .description("Displays your health data.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WidgetHealth_Previews: PreviewProvider {
    static var previews: some View {
        WidgetHealthEntryView(entry: HealthEntry(date: Date(), stepCount: 1000, heartRate: 70, activeEnergy: 200, exerciseMinutes: 30, sleepHours: 8))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

