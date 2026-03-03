import SwiftUI

/// The "back page" week overview.
/// Renders 7 columns directly aligned with the HorizontalCalendarView strip above.
struct WeekOverviewView: View {
    @ObservedObject var vm: DayScheduleViewModel
    /// The exact 7 dates currently shown in the calendar strip
    let weekDates: [Date]
    
    // Layout
    private let hourLabelWidth: CGFloat = 32
    private let hourHeight: CGFloat = 44
    private let startHour: Int = 6
    private let endHour: Int = 23
    private let miniPillSize: CGFloat = 40
    
    private var totalHours: Int { endHour - startHour }
    private var gridHeight: CGFloat { CGFloat(totalHours) * hourHeight }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                // Hour labels on the far left
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { hour in
                        Text(String(format: "%02d", hour) + "\u{2070}\u{2070}")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.35))
                            .frame(height: hourHeight, alignment: .top)
                            .frame(width: hourLabelWidth, alignment: .trailing)
                    }
                }
                .padding(.trailing, 2)
                
                // 7 day columns — each takes equal width
                ForEach(Array(weekDates.enumerated()), id: \.offset) { _, date in
                    dayColumn(for: date)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: gridHeight)
    }
    
    // MARK: - Day Column
    @ViewBuilder
    private func dayColumn(for date: Date) -> some View {
        let isSelected = vm.calendar.isDate(date, inSameDayAs: vm.selectedDate)
        let dayTasks = vm.tasksFor(date: date).sorted { $0.startTime < $1.startTime }
        
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            
            ZStack(alignment: .top) {
                
                // Baseline line — always visible
                Path { p in
                    p.move(to: CGPoint(x: centerX, y: 0))
                    p.addLine(to: CGPoint(x: centerX, y: gridHeight))
                }
                .stroke(
                    Color.gray.opacity(isSelected ? 0.25 : 0.12),
                    lineWidth: 1
                )
                
                if !dayTasks.isEmpty {
                    // Gradient connecting lines between consecutive tasks
                    if dayTasks.count >= 2 {
                        ForEach(0..<dayTasks.count - 1, id: \.self) { i in
                            let task = dayTasks[i]
                            let nextTask = dayTasks[i + 1]
                            
                            let y1 = yFor(task.startTime) + pillH(for: task)
                            let y2 = yFor(nextTask.startTime)
                            
                            if y2 > y1 {
                                let c1 = isSelected ? task.color : task.color.opacity(0.2)
                                let c2 = isSelected ? nextTask.color : nextTask.color.opacity(0.2)
                                
                                Path { p in
                                    p.move(to: CGPoint(x: centerX, y: y1))
                                    p.addLine(to: CGPoint(x: centerX, y: y2))
                                }
                                .stroke(
                                    LinearGradient(colors: [c1, c2], startPoint: .top, endPoint: .bottom),
                                    lineWidth: isSelected ? 2.5 : 1.5
                                )
                            }
                        }
                    }
                    
                    // Solid colored line through each task's own duration
                    ForEach(dayTasks) { task in
                        let y = yFor(task.startTime)
                        let h = pillH(for: task)
                        let c = isSelected ? task.color : task.color.opacity(0.2)
                        
                        Path { p in
                            p.move(to: CGPoint(x: centerX, y: y))
                            p.addLine(to: CGPoint(x: centerX, y: y + h))
                        }
                        .stroke(c, lineWidth: isSelected ? 2.5 : 1.5)
                    }
                    
                    // Mini pill icons
                    ForEach(dayTasks) { task in
                        let y = yFor(task.startTime)
                        let h = pillH(for: task)
                        
                        miniPill(task: task, isSelected: isSelected, height: h)
                            .position(x: centerX, y: y + h / 2)
                    }
                }
            }
            .frame(height: gridHeight)
        }
        .frame(height: gridHeight)
    }
    
    // MARK: - Mini Pill
    private func miniPill(task: TaskItem, isSelected: Bool, height: CGFloat) -> some View {
        ZStack {
            if height > miniPillSize * 1.5 {
                Capsule()
                    .fill(isSelected ? task.color : Color.gray.opacity(0.3))
                    .frame(width: miniPillSize, height: height)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.white.opacity(0.15) : Color.clear, lineWidth: 2)
                    )
            } else {
                Circle()
                    .fill(isSelected ? task.color : Color.gray.opacity(0.3))
                    .frame(width: miniPillSize, height: miniPillSize)
            }
            
            Image(systemName: task.icon ?? "doc.text.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isSelected ? .white : task.color.opacity(0.6))
        }
    }
    
    // MARK: - Helpers
    private func yFor(_ date: Date) -> CGFloat {
        let comps = vm.calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let minsSinceStart = CGFloat(max(0, (h - startHour) * 60 + m))
        return minsSinceStart * (hourHeight / 60.0)
    }
    
    private func pillH(for task: TaskItem) -> CGFloat {
        let h = CGFloat(task.durationMinutes) * (hourHeight / 60.0)
        return max(miniPillSize, h)
    }
}
