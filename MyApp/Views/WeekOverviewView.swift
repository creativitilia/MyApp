import SwiftUI

struct WeekOverviewView: View {
    @ObservedObject var vm: DayScheduleViewModel
    let weekDates: [Date]
    
    private let miniPillMinSize: CGFloat = 50      // minimum pill diameter (for short tasks)
    private let hourLabelWidth: CGFloat = 44
    private let verticalPadding: CGFloat = 20
    private let calendarStripHPadding: CGFloat = 4 // must match HorizontalCalendarView .padding(.horizontal, 4)
    
    // MARK: - Computed
    
    private var allWeekTasks: [TaskItem] {
        weekDates.flatMap { vm.tasksFor(date: $0) }
    }
    
    private var hasAnyTasks: Bool { !allWeekTasks.isEmpty }
    
    /// Collect every unique time boundary (task start & end) across the whole week.
    /// These are the ONLY times we show labels for.
    private var timeBoundaries: [Int] {
        var set = Set<Int>()
        for task in allWeekTasks {
            set.insert(vm.minutesSinceMidnight(for: task.startTime))
            let end = task.startTime.addingTimeInterval(task.duration)
            set.insert(vm.minutesSinceMidnight(for: end))
        }
        return set.sorted()
    }
    
    /// Earliest minute across all tasks in the week
    private var earliestMinute: Int {
        timeBoundaries.first ?? 0
    }
    
    /// Latest minute across all tasks in the week
    private var latestMinute: Int {
        timeBoundaries.last ?? 1
    }
    
    /// Total minute span
    private var totalMinuteSpan: Int {
        max(1, latestMinute - earliestMinute)
    }
    
    var body: some View {
        GeometryReader { geo in
            if !hasAnyTasks {
                Color.clear
            } else {
                let screenWidth = geo.size.width
                let availableH = geo.size.height - verticalPadding * 2
                
                // pixels per minute — scale to fill available height
                let ppm = max(1.2, availableH / CGFloat(totalMinuteSpan))
                let contentH = CGFloat(totalMinuteSpan) * ppm + verticalPadding * 2
                let needsScroll = contentH > geo.size.height + 1
                
                let calColumnWidth = (screenWidth - calendarStripHPadding * 2) / 7.0
                
                if needsScroll {
                    ScrollView(.vertical, showsIndicators: false) {
                        weekContent(ppm: ppm, contentH: contentH, screenWidth: screenWidth, calColumnWidth: calColumnWidth)
                    }
                } else {
                    weekContent(ppm: ppm, contentH: max(contentH, geo.size.height), screenWidth: screenWidth, calColumnWidth: calColumnWidth)
                }
            }
        }
    }
    
    // MARK: - Content
    
    private func weekContent(ppm: CGFloat, contentH: CGFloat, screenWidth: CGFloat, calColumnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Time labels — ONLY at task start/end boundaries
            ForEach(timeBoundaries, id: \.self) { minute in
                let y = yFor(minute: minute, ppm: ppm)
                timeLabel(minute: minute)
                    .position(x: hourLabelWidth / 2 + 2, y: y)
            }
            
            // Subtle grid lines at each boundary
            ForEach(timeBoundaries, id: \.self) { minute in
                let y = yFor(minute: minute, ppm: ppm)
                Path { p in
                    p.move(to: CGPoint(x: hourLabelWidth, y: y))
                    p.addLine(to: CGPoint(x: screenWidth, y: y))
                }
                .stroke(Color.gray.opacity(0.06), lineWidth: 0.5)
            }
            
            // Day columns — ONLY for days that have tasks
            ForEach(Array(weekDates.enumerated()), id: \.offset) { dayIndex, date in
                let centerX = calendarStripHPadding + (CGFloat(dayIndex) + 0.5) * calColumnWidth
                dayColumn(for: date, centerX: centerX, ppm: ppm, contentH: contentH)
            }
        }
        .frame(width: screenWidth, height: contentH)
    }
    
    // MARK: - Time Label (HH⁰⁰ format, only at task boundaries)
    
    private func timeLabel(minute: Int) -> some View {
        let hour = minute / 60
        let min = minute % 60
        let d = hour == 24 ? 0 : hour
        
        return HStack(spacing: 0) {
            Text(String(format: "%02d", d))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.5))
            Text(String(format: "%02d", min))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.4))
                .baselineOffset(4)
        }
    }
    
    // MARK: - Day Column
    
    private func dayColumn(for date: Date, centerX: CGFloat, ppm: CGFloat, contentH: CGFloat) -> some View {
        let isSelected = vm.calendar.isDate(date, inSameDayAs: vm.selectedDate)
        let dayTasks = vm.tasksFor(date: date).sorted { $0.startTime < $1.startTime }
        
        return ZStack {
            // Vertical line — ONLY if this day has tasks
            if !dayTasks.isEmpty {
                // Line from first task top to last task bottom
                let firstY = yFor(task: dayTasks.first!, isStart: true, ppm: ppm)
                let lastY = yFor(task: dayTasks.last!, isStart: false, ppm: ppm)
                
                Path { p in
                    p.move(to: CGPoint(x: centerX, y: firstY))
                    p.addLine(to: CGPoint(x: centerX, y: lastY))
                }
                .stroke(Color.gray.opacity(isSelected ? 0.2 : 0.1), lineWidth: 1)
            }
            
            if !dayTasks.isEmpty {
                // Gradient lines between consecutive tasks
                if dayTasks.count >= 2 {
                    ForEach(0..<dayTasks.count - 1, id: \.self) { i in
                        let t = dayTasks[i]
                        let nt = dayTasks[i + 1]
                        // Line from bottom of current pill to top of next pill
                        let y1 = yFor(task: t, isStart: false, ppm: ppm)
                        let y2 = yFor(task: nt, isStart: true, ppm: ppm)
                        
                        if y2 > y1 + 2 {
                            Path { p in
                                p.move(to: CGPoint(x: centerX, y: y1))
                                p.addLine(to: CGPoint(x: centerX, y: y2))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        isSelected ? t.color : t.color.opacity(0.25),
                                        isSelected ? nt.color : nt.color.opacity(0.25)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: isSelected ? 5 : 2
                            )
                        }
                    }
                }
                
                // Task pills — height proportional to duration
                ForEach(dayTasks) { task in
                    let topY = yFor(task: task, isStart: true, ppm: ppm)
                    let bottomY = yFor(task: task, isStart: false, ppm: ppm)
                    let pillH = max(miniPillMinSize, bottomY - topY)
                    let centerY = topY + pillH / 2
                    
                    ZStack {
                        Capsule()
                            .fill(isSelected ? task.color : Color.gray.opacity(0.3))
                            .frame(width: miniPillMinSize, height: pillH)
                        
                        Image(systemName: task.icon ?? "doc.text.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isSelected ? .white : task.color.opacity(0.6))
                    }
                    .position(x: centerX, y: centerY)
                }
            }
        }
        .frame(height: contentH)
    }
    
    // MARK: - Y Position Helpers
    
    /// Convert a minute-of-day value to a Y coordinate
    private func yFor(minute: Int, ppm: CGFloat) -> CGFloat {
        let minsFromStart = CGFloat(minute - earliestMinute)
        return verticalPadding + minsFromStart * ppm
    }
    
    /// Get Y for the top (isStart=true) or bottom (isStart=false) of a task's pill
    private func yFor(task: TaskItem, isStart: Bool, ppm: CGFloat) -> CGFloat {
        if isStart {
            return yFor(minute: vm.minutesSinceMidnight(for: task.startTime), ppm: ppm)
        } else {
            let end = task.startTime.addingTimeInterval(task.duration)
            return yFor(minute: vm.minutesSinceMidnight(for: end), ppm: ppm)
        }
    }
}
