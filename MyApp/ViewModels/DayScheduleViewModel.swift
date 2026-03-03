import Foundation
import SwiftUI
import Combine

// Determines exactly where and how a task should be drawn
struct TaskLayout {
    let task: TaskItem
    let yPos: CGFloat
    let height: CGFloat
    let zIndex: Double
    let showOverlapWarning: Bool
    let warningYPos: CGFloat
    let isEyeOverlap: Bool      // NEW: true = "eye" junction effect, false = normal pill
}

final class DayScheduleViewModel: ObservableObject {
    @Published private var allTasks: [TaskItem] = []
    
    @Published var selectedDate: Date = Date()
    @Published var currentTime: Date = Date()
    
    let pixelsPerMinute: CGFloat = 2.0
    let minuteSnap: Int = 5
    let timeColumnWidth: CGFloat = 65
    let pillWidth: CGFloat = 48          // NEW: shared constant for the capsule width

    private let store: TaskStore
    let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()

    init(store: TaskStore = TaskStore()) {
        self.store = store
        self.allTasks = store.load().sorted(by: { $0.startTime < $1.startTime })
        
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.currentTime = date
            }
            .store(in: &cancellables)
    }
    
    var tasks: [TaskItem] {
        allTasks.filter { calendar.isDate($0.startTime, inSameDayAs: selectedDate) }
    }

    func tasksFor(date: Date) -> [TaskItem] {
        allTasks.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    
    // MARK: - THE OVERLAP ENGINE
    var layoutAttributes: [TaskLayout] {
        var layouts = [TaskLayout]()
        let dayTasks = tasks.sorted { $0.startTime < $1.startTime }
        
        // We track each layout's "effective bottom" for chaining overlaps
        // effectiveBottom = yPos + height of the pill as drawn
        var prevEffectiveY: CGFloat = 0
        var prevEffectiveHeight: CGFloat = 0
        
        for (index, task) in dayTasks.enumerated() {
            let naturalY = yPosition(for: task.startTime)
            let h = height(for: task)
            var y = naturalY
            var showWarning = false
            var warnY: CGFloat = 0
            var isEye = false
            
            if index > 0 {
                let prevTask = dayTasks[index - 1]
                let prevEnd = prevTask.startTime.addingTimeInterval(prevTask.duration)
                
                // Overlap detected!
                if task.startTime < prevEnd {
                    // Calculate how many minutes of overlap exist
                    let overlapSeconds = prevEnd.timeIntervalSince(task.startTime)
                    let overlapMinutes = overlapSeconds / 60.0
                    
                    showWarning = true
                    
                    if overlapMinutes >= 10 {
                        // ── EYE EFFECT ──
                        // Push the second pill so its top overlaps the first pill's bottom
                        // by exactly the capsule's rounded-end diameter (pillWidth).
                        // This creates the "vesica piscis" / eye cutout shape.
                        isEye = true
                        
                        let prevBottom = prevEffectiveY + prevEffectiveHeight
                        // The second pill's top should start pillWidth above the first pill's bottom
                        y = prevBottom - pillWidth
                        
                        // Clamp: never push the pill higher than its natural position
                        y = max(y, naturalY)
                        
                        // Warning label sits right at the junction center (the eye)
                        warnY = y + (pillWidth / 2) - 8
                    } else {
                        // ── MINOR OVERLAP (< 10 min) ──
                        // Render as two normal separate pills at their natural Y positions.
                        // No eye effect, just show the warning label between them.
                        isEye = false
                        y = naturalY
                        
                        let prevCenter = prevEffectiveY + (prevEffectiveHeight / 2)
                        let currentCenter = y + (h / 2)
                        warnY = ((prevCenter + currentCenter) / 2) - 8
                    }
                }
            }
            
            // Z-Index logic:
            // - For eye overlaps: the SECOND (lower) pill must be ON TOP so its dark
            //   stroke cuts into the first pill, creating the eye illusion.
            //   We give the first pill a lower z-index, second pill a higher one.
            // - For normal pills: earlier tasks get higher z-index (existing behavior).
            let z: Double
            if isEye {
                z = Double(index) // Higher index = higher z = renders on top
            } else {
                z = Double(-index) // Lower index = higher z (original behavior)
            }
            
            layouts.append(TaskLayout(
                task: task,
                yPos: y,
                height: h,
                zIndex: z,
                showOverlapWarning: showWarning,
                warningYPos: warnY,
                isEyeOverlap: isEye
            ))
            
            prevEffectiveY = y
            prevEffectiveHeight = h
        }
        return layouts
    }

    // MARK: - CRUD
    func addTask(_ task: TaskItem) {
        allTasks.append(task)
        sortAndPersist()
    }

    func updateTask(_ updated: TaskItem) {
        guard let idx = allTasks.firstIndex(where: { $0.id == updated.id }) else { return }
        allTasks[idx] = updated
        sortAndPersist()
    }

    func deleteTask(_ task: TaskItem) {
        allTasks.removeAll { $0.id == task.id }
        sortAndPersist()
    }
    
    func toggleCompletion(for task: TaskItem) {
        if let idx = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[idx].isCompleted.toggle()
            sortAndPersist()
        }
    }
    
    private func sortAndPersist() {
        allTasks.sort(by: { $0.startTime < $1.startTime })
        store.save(tasks: allTasks)
    }

    // MARK: - Layout Helpers
    func minutesSinceMidnight(for date: Date) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    func yPosition(for date: Date) -> CGFloat {
        CGFloat(minutesSinceMidnight(for: date)) * pixelsPerMinute
    }

    func height(for task: TaskItem) -> CGFloat {
        max(44, CGFloat(task.durationMinutes) * pixelsPerMinute)
    }

    func timelineHeight() -> CGFloat {
        CGFloat(24 * 60) * pixelsPerMinute
    }

    func hourLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}
