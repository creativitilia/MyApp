import Foundation
import SwiftUI
import Combine

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
    
    // MARK: - Adaptive Hour Range for Selected Day
    
    /// The hour range for the currently selected day, derived purely from tasks.
    /// Returns nil if no tasks exist for that day.
    var selectedDayHourRange: ClosedRange<Int>? {
        let dayTasks = tasks
        guard !dayTasks.isEmpty else { return nil }
        
        let earliest = dayTasks.min(by: { $0.startTime < $1.startTime })!
        let latest = dayTasks.max(by: {
            $0.startTime.addingTimeInterval($0.duration) < $1.startTime.addingTimeInterval($1.duration)
        })!
        
        let startHour = calendar.component(.hour, from: earliest.startTime)
        let endDate = latest.startTime.addingTimeInterval(latest.duration)
        let endHour = calendar.component(.hour, from: endDate)
        let endMinute = calendar.component(.minute, from: endDate)
        let ceiledEndHour = endMinute > 0 ? min(endHour + 1, 24) : max(endHour, startHour + 1)
        
        return max(0, startHour)...min(24, ceiledEndHour)
    }
    
    /// Adaptive pixels per minute for the selected day's hour range,
    /// given a specific available height.
    func adaptivePixelsPerMinute(availableHeight: CGFloat) -> CGFloat {
        guard let range = selectedDayHourRange else { return pixelsPerMinute }
        let totalMinutes = CGFloat(range.upperBound - range.lowerBound) * 60
        guard totalMinutes > 0 else { return pixelsPerMinute }
        // Use at least the default pixelsPerMinute, or stretch to fill
        return max(pixelsPerMinute, (availableHeight - 40) / totalMinutes)
    }
    
    /// Minutes from the start of the hour range (not midnight) for a given date
    func adaptiveMinutesFromRangeStart(for date: Date) -> Int {
        guard let range = selectedDayHourRange else { return minutesSinceMidnight(for: date) }
        let mins = minutesSinceMidnight(for: date)
        return mins - (range.lowerBound * 60)
    }
    
    /// Y position using adaptive layout
    func adaptiveYPosition(for date: Date, ppm: CGFloat) -> CGFloat {
        CGFloat(adaptiveMinutesFromRangeStart(for: date)) * ppm
    }
    
    /// Height using adaptive ppm
    func adaptiveHeight(for task: TaskItem, ppm: CGFloat) -> CGFloat {
        max(44, CGFloat(task.durationMinutes) * ppm)
    }
    
    /// Total adaptive timeline height
    func adaptiveTimelineHeight(ppm: CGFloat) -> CGFloat {
        guard let range = selectedDayHourRange else { return 0 }
        return CGFloat(range.upperBound - range.lowerBound) * 60 * ppm
    }
    
    /// Adaptive layout attributes (replaces the fixed layoutAttributes for the day view)
    func adaptiveLayoutAttributes(ppm: CGFloat) -> [TaskLayout] {
        var layouts = [TaskLayout]()
        let dayTasks = tasks.sorted { $0.startTime < $1.startTime }
        
        var prevEffectiveY: CGFloat = 0
        var prevEffectiveHeight: CGFloat = 0
        
        for (index, task) in dayTasks.enumerated() {
            let naturalY = adaptiveYPosition(for: task.startTime, ppm: ppm)
            let h = adaptiveHeight(for: task, ppm: ppm)
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
            
            layouts.append(TaskLayout(
                task: task, yPos: y, height: h, displayHeight: h,
                zIndex: z, showOverlapWarning: showWarning,
                warningYPos: warnY, isEyeOverlap: isEye
            ))
            
            prevEffectiveY = y
            prevEffectiveHeight = h
        }
        return layouts
    }
    
    // MARK: - Week Dates (Single Source of Truth)
    func weekDates(for date: Date) -> [Date] {
        let target = calendar.startOfDay(for: date)
        let wd = calendar.component(.weekday, from: target)
        let daysBackToMonday = (wd + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysBackToMonday, to: target) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
    
    func mondayOf(date: Date) -> Date {
        let target = calendar.startOfDay(for: date)
        let wd = calendar.component(.weekday, from: target)
        let daysBack = (wd + 5) % 7
        return calendar.date(byAdding: .day, value: -daysBack, to: target) ?? target
    }
    
    // MARK: - THE OVERLAP ENGINE (kept for backward compat, uses fixed 24h)
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
                task: task, yPos: y, height: h, displayHeight: displayH,
                zIndex: z, showOverlapWarning: showWarning,
                warningYPos: warnY, isEyeOverlap: isEye
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

    // MARK: - Layout Helpers (fixed 24h — kept for backward compat)
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
