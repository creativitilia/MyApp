import SwiftUI

/// The "back page" week overview.
/// 7 columns directly under the calendar strip — no hour labels, full-width aligned.
struct WeekOverviewView: View {
    @ObservedObject var vm: DayScheduleViewModel
    let weekDates: [Date]
    
    private let miniPillSize: CGFloat = 40
    
    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let columnWidth = geo.size.width / CGFloat(max(weekDates.count, 1))
            
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { _, date in
                    dayColumn(for: date, totalHeight: totalHeight)
                        .frame(width: columnWidth, height: totalHeight)
                }
            }
        }
    }
    
    // MARK: - Day Column
    @ViewBuilder
    private func dayColumn(for date: Date, totalHeight: CGFloat) -> some View {
        let isSelected = vm.calendar.isDate(date, inSameDayAs: vm.selectedDate)
        let dayTasks = vm.tasksFor(date: date).sorted { $0.startTime < $1.startTime }
        
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            
            ZStack(alignment: .top) {
                
                // ── BASELINE LINE — always visible on every column ──
                Path { p in
                    p.move(to: CGPoint(x: centerX, y: 0))
                    p.addLine(to: CGPoint(x: centerX, y: totalHeight))
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
                            
                            let y1 = yFor(task.startTime, totalHeight: totalHeight) + pillH(for: task, totalHeight: totalHeight)
                            let y2 = yFor(nextTask.startTime, totalHeight: totalHeight)
                            
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
                        let y = yFor(task.startTime, totalHeight: totalHeight)
                        let h = pillH(for: task, totalHeight: totalHeight)
                        let c = isSelected ? task.color : task.color.opacity(0.2)
                        
                        Path { p in
                            p.move(to: CGPoint(x: centerX, y: y))
                            p.addLine(to: CGPoint(x: centerX, y: y + h))
                        }
                        .stroke(c, lineWidth: isSelected ? 3 : 1.5)
                    }
                    
                    // ── MINI PILL ICONS ──
                    ForEach(dayTasks) { task in
                        let y = yFor(task.startTime, totalHeight: totalHeight)
                        let h = pillH(for: task, totalHeight: totalHeight)
                        
                        miniPill(task: task, isSelected: isSelected, height: h)
                            .position(x: centerX, y: y + h / 2)
                    }
                }
            }
        }
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
    
    /// Map time-of-day to Y position using full available height.
    /// 00:00 = 0, 23:59 = totalHeight
    private func yFor(_ date: Date, totalHeight: CGFloat) -> CGFloat {
        let comps = vm.calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let totalMinutes = CGFloat(h * 60 + m)
        let dayMinutes: CGFloat = 24 * 60
        return (totalMinutes / dayMinutes) * totalHeight
    }
    
    /// Pill height proportional to task duration.
    private func pillH(for task: TaskItem, totalHeight: CGFloat) -> CGFloat {
        let dayMinutes: CGFloat = 24 * 60
        let h = (CGFloat(task.durationMinutes) / dayMinutes) * totalHeight
        return max(miniPillSize, h)
    }
}
