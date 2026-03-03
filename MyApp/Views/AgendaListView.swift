import SwiftUI

/// Flat agenda list shown when dragging down the timeline.
/// Displays tasks in chronological order with annotated time gaps.
struct AgendaListView: View {
    @ObservedObject var vm: DayScheduleViewModel
    let onTaskTap: (TaskItem) -> Void
    let onAddTask: () -> Void
    
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let cardBackground = Color(red: 0.15, green: 0.15, blue: 0.17)
    
    var body: some View {
        let dayTasks = vm.tasks.sorted { $0.startTime < $1.startTime }
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Drag Handle
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                
                if dayTasks.isEmpty {
                    emptyState
                } else {
                    // Render each task with gaps between them
                    ForEach(Array(dayTasks.enumerated()), id: \.element.id) { index, task in
                        
                        // Gap annotation BEFORE this task (between previous task's end and this task's start)
                        if index == 0 {
                            // Gap from start of day to first task — only if task doesn't start at midnight
                            let startOfDay = vm.calendar.startOfDay(for: vm.selectedDate)
                            let gapMinutes = task.startTime.timeIntervalSince(startOfDay) / 60
                            if gapMinutes > 0 {
                                // Don't show gap before first task — just start with the task
                            }
                        } else {
                            let prevTask = dayTasks[index - 1]
                            let prevEnd = prevTask.startTime.addingTimeInterval(prevTask.duration)
                            let gapSeconds = task.startTime.timeIntervalSince(prevEnd)
                            let gapMinutes = gapSeconds / 60
                            
                            if gapMinutes > 0 {
                                gapAnnotation(minutes: gapMinutes, afterTime: prevEnd, beforeTime: task.startTime)
                            }
                        }
                        
                        // The task row
                        agendaRow(task: task)
                            .onTapGesture { onTaskTap(task) }
                    }
                    
                    // Gap after last task
                    if let lastTask = dayTasks.last {
                        let lastEnd = lastTask.startTime.addingTimeInterval(lastTask.duration)
                        let endOfDay = vm.calendar.startOfDay(for: vm.selectedDate).addingTimeInterval(24 * 3600)
                        let remainingMinutes = endOfDay.timeIntervalSince(lastEnd) / 60
                        
                        if remainingMinutes > 60 {
                            gapAnnotation(minutes: remainingMinutes, afterTime: lastEnd, beforeTime: endOfDay)
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Task Row
    private func agendaRow(task: TaskItem) -> some View {
        HStack(spacing: 14) {
            // Pill icon
            ZStack {
                Circle()
                    .fill(task.isCompleted ? task.color.opacity(0.3) : task.color)
                    .frame(width: 52, height: 52)
                
                Image(systemName: task.isCompleted ? "checkmark" : (task.icon ?? "doc.text.fill"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(task.isCompleted ? task.color : .white)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 3) {
                let endTime = task.startTime.addingTimeInterval(task.duration)
                
                if task.isCompleted {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    // Show remaining time if task is currently active
                    let now = Date()
                    if task.startTime <= now && endTime > now {
                        let remainingMin = Int(endTime.timeIntervalSince(now) / 60)
                        Text("\(remainingMin)m remaining")
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text("\(task.startTime.formatted(date: .omitted, time: .shortened)) \(Image(systemName: "repeat"))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(task.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(task.isCompleted ? .gray : .white)
                    .strikethrough(task.isCompleted)
            }
            
            Spacer()
            
            // Checkbox
            Button(action: { vm.toggleCompletion(for: task) }) {
                Circle()
                    .strokeBorder(task.isCompleted ? task.color : task.color.opacity(0.5), lineWidth: 2)
                    .background(Circle().fill(task.isCompleted ? task.color : Color.clear))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .opacity(task.isCompleted ? 1 : 0)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Gap Annotation
    private func gapAnnotation(minutes: Double, afterTime: Date, beforeTime: Date) -> some View {
        VStack(spacing: 8) {
            // Time labels
            HStack {
                Text(afterTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.weight(.medium))
                    .foregroundColor(Color.gray.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Gap content
            HStack(spacing: 8) {
                Image(systemName: gapIcon(minutes: minutes))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(gapMessage(minutes: minutes))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Add Task button
            Button(action: onAddTask) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(themePink)
                    Text("Add Task")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(themePink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(cardBackground)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "sun.max.fill")
                .font(.system(size: 48))
                .foregroundColor(themePink.opacity(0.5))
            Text("No tasks today")
                .font(.title3.weight(.medium))
                .foregroundColor(.gray)
            
            Button(action: onAddTask) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Task")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(themePink)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(cardBackground)
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Helpers
    private func gapIcon(minutes: Double) -> String {
        if minutes >= 480 { return "timer" }
        if minutes >= 120 { return "timer" }
        if minutes >= 30 { return "zzz" }
        return "clock"
    }
    
    private func gapMessage(minutes: Double) -> String {
        if minutes >= 60 {
            let hours = Int(minutes / 60)
            let mins = Int(minutes) % 60
            if mins == 0 {
                return "Dream big with \(hours)h."
            }
            return "Dream big with \(hours)h \(mins)m."
        }
        if minutes >= 30 {
            return "Downtime—recharge complete."
        }
        return "\(Int(minutes))m free"
    }
}
