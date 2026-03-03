import SwiftUI

/// The "back page" week overview with adaptive hour labels.
/// - Scans all 7 days to find the earliest task start and latest task end
/// - Only shows hours in that range
/// - Spacing adapts: few hours = compact (fits screen), many hours = expanded (scrollable)
/// - Hour labels on the left in "06⁰⁰" superscript style
struct WeekOverviewView: View {
    @ObservedObject var vm: DayScheduleViewModel
    let weekDates: [Date]
    
    private let miniPillSize: CGFloat = 40
    private let hourLabelWidth: CGFloat = 44
    /// Minimum pixels per hour — ensures pills are always readable
    private let minPixelsPerHour: CGFloat = 60
    /// Padding above first hour and below last hour
    private let verticalPadding: CGFloat = 30
    
    // MARK: - Computed: Hour Range from task data
    
    /// All tasks across the 7 days of this week
    private var allWeekTasks: [TaskItem] {
        weekDates.flatMap { vm.tasksFor(date: $0) }
    }
    
    /// Earliest task start hour (floored). nil if no tasks.
    private var earliestHour: Int? {
        guard let earliest = allWeekTasks.min(by: { $0.startTime < $1.startTime }) else { return nil }
        return vm.calendar.component(.hour, from: earliest.startTime)
    }
    
    /// Latest task end hour (ceiled). nil if no tasks.
    private var latestHour: Int? {
        guard let latest = allWeekTasks.max(by: {
            $0.startTime.addingTimeInterval($0.duration) < $1.startTime.addingTimeInterval($1.duration)
        }) else { return nil }
        let endDate = latest.startTime.addingTimeInterval(latest.duration)
        let endHour = vm.calendar.component(.hour, from: endDate)
        let endMinute = vm.calendar.component(.minute, from: endDate)
        // Ceil: if task ends at 14:30, we need to show up to 15:00
        return endMinute > 0 ? min(endHour + 1, 24) : max(endHour, 1)
    }
    
    /// The range of hours to display
    private var hourRange: ClosedRange<Int> {
        guard let first = earliestHour, let last = latestHour else {
            // No tasks — show a default range
            return 6...22
        }
        // Ensure at least 1 hour span
        let lo = max(0, first)
        let hi = max(lo + 1, min(24, last))
        return lo...hi
    }
    
    /// Number of hours in the range
    private var hourCount: Int {
        hourRange.upperBound - hourRange.lowerBound
    }
    
    var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height - verticalPadding * 2
            // Adaptive: use available height if it fits, otherwise expand
            let naturalPPH = hourCount > 0 ? availableHeight / CGFloat(hourCount) : minPixelsPerHour
            let pixelsPerHour = max(minPixelsPerHour, naturalPPH)
            let contentHeight = CGFloat(hourCount) * pixelsPerHour + verticalPadding * 2
            let needsScroll = contentHeight > geo.size.height + 1
            let columnsWidth = geo.size.width - hourLabelWidth
            let columnWidth = columnsWidth / CGFloat(max(weekDates.count, 1))
            
            if needsScroll {
                ScrollView(.vertical, showsIndicators: false) {
                    weekContent(
                        pixelsPerHour: pixelsPerHour,
                        contentHeight: contentHeight,
                        columnWidth: columnWidth,
                        columnsWidth: columnsWidth
                    )
                }
            } else {
                weekContent(
                    pixelsPerHour: pixelsPerHour,
                    contentHeight: max(contentHeight, geo.size.height),
                    columnWidth: columnWidth,
                    columnsWidth: columnsWidth
                )
            }
        }
    }
    
    // MARK: - Week Content (hour labels + 7 columns)
    
    private func weekContent(
        pixelsPerHour: CGFloat,
        contentHeight: CGFloat,
        columnWidth: CGFloat,
        columnsWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            // ── HOUR LABELS on the left ──
            ForEach(hourRange.lowerBound..<hourRange.upperBound, id: \.self) { hour in
                let y = verticalPadding + CGFloat(hour - hourRange.lowerBound) * pixelsPerHour
                hourLabel(hour: hour)
                    .offset(x: 0, y: y - 7) // -7 to center text on the line
            }
            
            // ── HOUR GRID LINES (subtle) ──
            ForEach(hourRange.lowerBound..<hourRange.upperBound, id: \.self) { hour in
                let y = verticalPadding + CGFloat(hour - hourRange.lowerBound) * pixelsPerHour
                Path { p in
                    p.move(to: CGPoint(x: hourLabelWidth, y: y))
                    p.addLine(to: CGPoint(x: hourLabelWidth + columnsWidth, y: y))
                }
                .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
            }
            
            // ── 7 DAY COLUMNS ──
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { _, date in
                    dayColumn(
                        for: date,
                        pixelsPerHour: pixelsPerHour,
                        contentHeight: contentHeight,
                        columnWidth: columnWidth
                    )
                    .frame(width: columnWidth)
                }
            }
            .offset(x: hourLabelWidth)
        }
        .frame(height: contentHeight)
    }
    
    // MARK: - Hour Label (superscript style like Structured: "06⁰⁰")
    
    private func hourLabel(hour: Int) -> some View {
        let displayHour = hour == 24 ? 0 : hour
        return HStack(spacing: 0) {
            Text(String(format: "%02d", displayHour))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.5))
            Text("⁰⁰")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.4))
                .baselineOffset(4)
        }
        .frame(width: hourLabelWidth, alignment: .leading)
        .padding(.leading, 4)
    }
    
    // MARK: - Day Column
    
    @ViewBuilder
    private func dayColumn(
        for date: Date,
        pixelsPerHour: CGFloat,
        contentHeight: CGFloat,
        columnWidth: CGFloat
    ) -> some View {
        let isSelected = vm.calendar.isDate(date, inSameDayAs: vm.selectedDate)
        let dayTasks = vm.tasksFor(date: date).sorted { $0.startTime < $1.startTime }
        let centerX = columnWidth / 2
        
        ZStack(alignment: .top) {
            
            // ── BASELINE LINE ──
            Path { p in
                p.move(to: CGPoint(x: centerX, y: 0))
                p.addLine(to: CGPoint(x: centerX, y: contentHeight))
            }
            .stroke(
                Color.gray.opacity(isSelected ? 0.3 : 0.15),
                lineWidth: 1
            )
            
            if !dayTasks.isEmpty {
                
                // ── GRADIENT LINES between consecutive tasks ──
                if dayTasks.count >= 2 {
                    ForEach(0..<dayTasks.count - 1, id: \.self) { i in
                        let task = dayTasks[i]
                        let nextTask = dayTasks[i + 1]
                        
                        let y1 = yFor(task.startTime, pixelsPerHour: pixelsPerHour)
                            + pillH(for: task, pixelsPerHour: pixelsPerHour)
                        let y2 = yFor(nextTask.startTime, pixelsPerHour: pixelsPerHour)
                        
                        if y2 > y1 {
                            let c1 = isSelected ? task.color : task.color.opacity(0.2)
                            let c2 = isSelected ? nextTask.color : nextTask.color.opacity(0.2)
                            
                            Path { p in
                                p.move(to: CGPoint(x: centerX, y: y1))
                                p.addLine(to: CGPoint(x: centerX, y: y2))
                            }
                            .stroke(
                                LinearGradient(colors: [c1, c2], startPoint: .top, endPoint: .bottom),
                                lineWidth: isSelected ? 3 : 1.5
                            )
                        }
                    }
                }
                
                // ── SOLID LINE through each task's duration ──
                ForEach(dayTasks) { task in
                    let y = yFor(task.startTime, pixelsPerHour: pixelsPerHour)
                    let h = pillH(for: task, pixelsPerHour: pixelsPerHour)
                    let c = isSelected ? task.color : task.color.opacity(0.2)
                    
                    Path { p in
                        p.move(to: CGPoint(x: centerX, y: y))
                        p.addLine(to: CGPoint(x: centerX, y: y + h))
                    }
                    .stroke(c, lineWidth: isSelected ? 3 : 1.5)
                }
                
                // ── MINI PILL ICONS ──
                ForEach(dayTasks) { task in
                    let y = yFor(task.startTime, pixelsPerHour: pixelsPerHour)
                    let h = pillH(for: task, pixelsPerHour: pixelsPerHour)
                    
                    miniPill(task: task, isSelected: isSelected, height: h)
                        .position(x: centerX, y: y + h / 2)
                }
            }
        }
        .frame(height: contentHeight)
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
    
    /// Map time-of-day → Y position relative to the hourRange.
    /// hourRange.lowerBound:00 = verticalPadding, each hour = pixelsPerHour
    private func yFor(_ date: Date, pixelsPerHour: CGFloat) -> CGFloat {
        let comps = vm.calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let minutesSinceRangeStart = CGFloat((h - hourRange.lowerBound) * 60 + m)
        return verticalPadding + (minutesSinceRangeStart / 60.0) * pixelsPerHour
    }
    
    /// Pill height proportional to task duration using adaptive pixelsPerHour.
    private func pillH(for task: TaskItem, pixelsPerHour: CGFloat) -> CGFloat {
        let h = (CGFloat(task.durationMinutes) / 60.0) * pixelsPerHour
        return max(miniPillSize, h)
    }
}
