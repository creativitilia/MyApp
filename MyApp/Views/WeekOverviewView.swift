import SwiftUI

struct WeekOverviewView: View {
    @ObservedObject var vm: DayScheduleViewModel
    let weekDates: [Date]
    
    private let miniPillSize: CGFloat = 36
    private let hourLabelWidth: CGFloat = 40
    private let minPixelsPerHour: CGFloat = 80
    private let verticalPadding: CGFloat = 20
    private let calendarStripHPadding: CGFloat = 4  // must match HorizontalCalendarView .padding(.horizontal, 4)
    
    // MARK: - Computed
    
    private var allWeekTasks: [TaskItem] {
        weekDates.flatMap { vm.tasksFor(date: $0) }
    }
    
    private var hasAnyTasks: Bool { !allWeekTasks.isEmpty }
    
    private var earliestHour: Int? {
        guard let e = allWeekTasks.min(by: { $0.startTime < $1.startTime }) else { return nil }
        return vm.calendar.component(.hour, from: e.startTime)
    }
    
    private var latestHour: Int? {
        guard let l = allWeekTasks.max(by: {
            $0.startTime.addingTimeInterval($0.duration) < $1.startTime.addingTimeInterval($1.duration)
        }) else { return nil }
        let end = l.startTime.addingTimeInterval(l.duration)
        let h = vm.calendar.component(.hour, from: end)
        let m = vm.calendar.component(.minute, from: end)
        return m > 0 ? min(h + 1, 24) : max(h, 1)
    }
    
    private var hourRange: ClosedRange<Int> {
        guard let lo = earliestHour, let hi = latestHour else { return 0...0 }
        return max(0, lo)...max(max(0, lo) + 1, min(24, hi))
    }
    
    private var hourCount: Int { hourRange.upperBound - hourRange.lowerBound }
    
    var body: some View {
        GeometryReader { geo in
            if !hasAnyTasks {
                Color.clear
            } else {
                let screenWidth = geo.size.width
                let availableH = geo.size.height - verticalPadding * 2
                let pph = max(minPixelsPerHour, hourCount > 0 ? availableH / CGFloat(hourCount) : minPixelsPerHour)
                let contentH = CGFloat(hourCount) * pph + verticalPadding * 2
                let needsScroll = contentH > geo.size.height + 1
                
                // Match HorizontalCalendarView: it uses full width with .padding(.horizontal, 4)
                // Each day column center = calendarStripHPadding + (dayIndex + 0.5) * columnWidth
                let calColumnWidth = (screenWidth - calendarStripHPadding * 2) / 7.0
                
                if needsScroll {
                    ScrollView(.vertical, showsIndicators: false) {
                        weekContent(pph: pph, contentH: contentH, screenWidth: screenWidth, calColumnWidth: calColumnWidth)
                    }
                } else {
                    weekContent(pph: pph, contentH: max(contentH, geo.size.height), screenWidth: screenWidth, calColumnWidth: calColumnWidth)
                }
            }
        }
    }
    
    // MARK: - Content
    
    private func weekContent(pph: CGFloat, contentH: CGFloat, screenWidth: CGFloat, calColumnWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Hour labels
            ForEach(hourRange.lowerBound..<hourRange.upperBound, id: \.self) { hour in
                let y = verticalPadding + CGFloat(hour - hourRange.lowerBound) * pph
                hourLabel(hour: hour)
                    .offset(x: 0, y: y - 7)
            }
            
            // Hour grid lines
            ForEach(hourRange.lowerBound..<hourRange.upperBound, id: \.self) { hour in
                let y = verticalPadding + CGFloat(hour - hourRange.lowerBound) * pph
                Path { p in
                    p.move(to: CGPoint(x: hourLabelWidth, y: y))
                    p.addLine(to: CGPoint(x: screenWidth, y: y))
                }
                .stroke(Color.gray.opacity(0.08), lineWidth: 0.5)
            }
            
            // Day columns — positioned to match HorizontalCalendarView centers
            ForEach(Array(weekDates.enumerated()), id: \.offset) { dayIndex, date in
                let centerX = calendarStripHPadding + (CGFloat(dayIndex) + 0.5) * calColumnWidth
                dayColumn(for: date, centerX: centerX, pph: pph, contentH: contentH)
            }
        }
        .frame(width: screenWidth, height: contentH)
    }
    
    // MARK: - Hour Label
    
    private func hourLabel(hour: Int) -> some View {
        let d = hour == 24 ? 0 : hour
        return HStack(spacing: 0) {
            Text(String(format: "%02d", d))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.5))
            Text("⁰⁰")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.4))
                .baselineOffset(4)
        }
        .frame(width: hourLabelWidth, alignment: .leading)
        .padding(.leading, 4)
    }
    
    // MARK: - Day Column (absolute positioning)
    
    private func dayColumn(for date: Date, centerX: CGFloat, pph: CGFloat, contentH: CGFloat) -> some View {
        let isSelected = vm.calendar.isDate(date, inSameDayAs: vm.selectedDate)
        let dayTasks = vm.tasksFor(date: date).sorted { $0.startTime < $1.startTime }
        
        return ZStack {
            // Baseline vertical line
            Path { p in
                p.move(to: CGPoint(x: centerX, y: 0))
                p.addLine(to: CGPoint(x: centerX, y: contentH))
            }
            .stroke(Color.gray.opacity(isSelected ? 0.3 : 0.15), lineWidth: 1)
            
            if !dayTasks.isEmpty {
                // Gradient lines between consecutive tasks
                if dayTasks.count >= 2 {
                    ForEach(0..<dayTasks.count - 1, id: \.self) { i in
                        let t = dayTasks[i]
                        let nt = dayTasks[i + 1]
                        let y1 = yFor(t.startTime, pph: pph) + miniPillSize / 2
                        let y2 = yFor(nt.startTime, pph: pph) - miniPillSize / 2
                        
                        if y2 > y1 {
                            Path { p in
                                p.move(to: CGPoint(x: centerX, y: y1))
                                p.addLine(to: CGPoint(x: centerX, y: y2))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        isSelected ? t.color : t.color.opacity(0.2),
                                        isSelected ? nt.color : nt.color.opacity(0.2)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: isSelected ? 3 : 1.5
                            )
                        }
                    }
                }
                
                // Task circles (always circles, never capsules)
                ForEach(dayTasks) { task in
                    let y = yFor(task.startTime, pph: pph)
                    
                    ZStack {
                        Circle()
                            .fill(isSelected ? task.color : Color.gray.opacity(0.3))
                            .frame(width: miniPillSize, height: miniPillSize)
                        
                        Image(systemName: task.icon ?? "doc.text.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isSelected ? .white : task.color.opacity(0.6))
                    }
                    .position(x: centerX, y: y)
                }
            }
        }
        .frame(height: contentH)
    }
    
    // MARK: - Helpers
    
    private func yFor(_ date: Date, pph: CGFloat) -> CGFloat {
        let comps = vm.calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let minsFromStart = CGFloat((h - hourRange.lowerBound) * 60 + m)
        return verticalPadding + (minsFromStart / 60.0) * pph
    }
}
