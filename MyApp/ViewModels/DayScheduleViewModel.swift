import Foundation
import SwiftUI
import Combine

// Determines exactly where and how a task should be drawn
struct TaskLayout {
    let task: TaskItem
    let yPos: CGFloat
    let height: CGFloat
    let displayHeight: CGFloat
    let zIndex: Double
    let showOverlapWarning: Bool
    let warningYPos: CGFloat
    let isEyeOverlap: Bool
}

final class DayScheduleViewModel: ObservableObject {
    @Published private var allTasks: [TaskItem] = []
    
    @Published var selectedDate: Date = Date()
    @Published var currentTime: Date = Date()
    
    let pixelsPerMinute: CGFloat = 2.0
    let minuteSnap: Int = 5
    let timeColumnWidth: CGFloat = 65
    let pillWidth: CGFloat = 48

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
    
    // MARK: - Week Dates (Single Source of Truth)
    /// Returns the 7 dates of the week containing `date`,
    /// starting from Monday (ISO standard, matching Structured app).
    func weekDates(for date: Date) -> [Date] {
        let target = calendar.startOfDay(for: date)
        // weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let wd = calendar.component(.weekday, from: target)
        // Days back to Monday: Mon(2)→0, Tue(3)→1, Wed(4)→2, ..., Sun(1)→6
        let daysBackToMonday = (wd + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysBackToMonday, to: target) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
    
    // MARK: - THE OVERLAP ENGINE
    var layoutAttributes: [TaskLayout] {
        var layouts = [TaskLayout]()
        let dayTasks = tasks.sorted { $0.startTime < $1.startTime }
        
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
                
                if task.startTime < prevEnd {
                    let overlapSeconds = prevEnd.timeIntervalSince(task.startTime)
                    let overlapMinutes = overlapSeconds / 60.0
                    
                    showWarning = true
                    
                    if overlapMinutes >= 10 {
                        isEye = true
                        let prevBottom = prevEffectiveY + prevEffectiveHeight
                        y = prevBottom - pillWidth
                        y = max(y, naturalY)
                        warnY = y + (pillWidth / 2) - 8
                    } else {
                        isEye = false
                        y = naturalY
                        let prevCenter = prevEffectiveY + (prevEffectiveHeight / 2)
                        let currentCenter = y + (h / 2)
                        warnY = ((prevCenter + currentCenter) / 2) - 8
                    }
                }
            }
            
            let z: Double = isEye ? Double(index) : Double(-index)
            let displayH = h
            
            layouts.append(TaskLayout(
                task: task,
                yPos: y,
                height: h,
                displayHeight: displayH,
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
