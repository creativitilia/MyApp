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
    let timeColumnWidth: CGFloat = 50
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
    
    // MARK: - Hour Range for a set of tasks (used by WeekOverview)
    
    func hourRange(for taskList: [TaskItem]) -> ClosedRange<Int>? {
        guard !taskList.isEmpty else { return nil }
        
        let earliest = taskList.min(by: { $0.startTime < $1.startTime })!
        let latest = taskList.max(by: {
            $0.startTime.addingTimeInterval($0.duration) < $1.startTime.addingTimeInterval($1.duration)
        })!
        
        let startHour = calendar.component(.hour, from: earliest.startTime)
        let endDate = latest.startTime.addingTimeInterval(latest.duration)
        let endHour = calendar.component(.hour, from: endDate)
        let endMinute = calendar.component(.minute, from: endDate)
        let ceiledEndHour = endMinute > 0 ? min(endHour + 1, 24) : max(endHour, startHour + 1)
        
        return max(0, startHour)...min(24, ceiledEndHour)
    }
    
    // MARK: - Week Dates
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

    func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func hourLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:00 a"
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}
