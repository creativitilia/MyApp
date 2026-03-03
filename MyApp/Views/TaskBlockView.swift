import SwiftUI

struct TaskBlockView: View {
    let task: TaskItem
    let height: CGFloat
    let isEyeOverlap: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    
    let pillWidth: CGFloat = 70
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    
    private var strokeWidth: CGFloat {
        isEyeOverlap ? 4 : 2
    }
    
    private var pillHeight: CGFloat {
        max(height, pillWidth)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            
            // 1. The Pill
            ZStack(alignment: .center) {
                Capsule()
                    .fill(task.isCompleted ? task.color.opacity(0.3) : task.color)
                    .frame(width: pillWidth, height: pillHeight)
                
                Image(systemName: task.isCompleted ? "checkmark" : (task.icon ?? "doc.text.fill"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(task.isCompleted ? task.color : .white)
            }
            .overlay(
                Capsule()
                    .stroke(darkBackground, lineWidth: strokeWidth)
            )
            .shadow(
                color: isEyeOverlap ? task.color.opacity(0.4) : .clear,
                radius: isEyeOverlap ? 4 : 0,
                x: 0, y: 0
            )
            .frame(width: pillWidth, height: pillHeight)
            
            // 2. Text — vertically centered with the pill
            VStack(alignment: .leading, spacing: 4) {
                let endTime = task.startTime.addingTimeInterval(task.duration)
                let durText: String = {
                    let mins = Int(task.durationMinutes)
                    if mins >= 60 {
                        let h = mins / 60
                        let m = mins % 60
                        return m > 0 ? "\(h) hr, \(m) min" : "\(h) hr"
                    }
                    return "\(mins) min"
                }()
                Text("\(task.startTime.formatted(date: .omitted, time: .shortened)) – \(endTime.formatted(date: .omitted, time: .shortened)) (\(durText))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(task.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            // 3. Checkbox — larger, full task color
            Button(action: onToggleComplete) {
                Circle()
                    .strokeBorder(task.isCompleted ? task.color : task.color, lineWidth: 2.5)
                    .background(Circle().fill(task.isCompleted ? task.color : Color.clear))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .opacity(task.isCompleted ? 1 : 0)
                    )
            }
        }
        .frame(height: pillHeight, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
