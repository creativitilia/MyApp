import SwiftUI

struct TaskBlockView: View {
    let task: TaskItem
    let height: CGFloat
    let isEyeOverlap: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    
    let pillWidth: CGFloat = 48
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    
    private var strokeWidth: CGFloat {
        isEyeOverlap ? 4 : 2
    }
    
    private var pillHeight: CGFloat {
        max(height, pillWidth)
    }
    
    private var pillCenterY: CGFloat {
        pillHeight / 2
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            
            // 1. The Pill
            ZStack(alignment: .center) {
                Capsule()
                    .fill(task.isCompleted ? task.color.opacity(0.3) : task.color)
                    .frame(width: pillWidth, height: pillHeight)
                
                Image(systemName: task.isCompleted ? "checkmark" : (task.icon ?? "doc.text.fill"))
                    .font(.system(size: 20, weight: .bold))
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
            
            // 2. Text
            VStack(alignment: .leading, spacing: 3) {
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
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(task.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: false, vertical: true)
            .offset(y: pillCenterY - 19)
            
            Spacer(minLength: 0)
            
            // 3. Checkbox
            Button(action: onToggleComplete) {
                Circle()
                    .strokeBorder(task.isCompleted ? task.color : task.color.opacity(0.5), lineWidth: 2)
                    .background(Circle().fill(task.isCompleted ? task.color : Color.clear))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .opacity(task.isCompleted ? 1 : 0)
                    )
            }
            .padding(.trailing, 16)
            .offset(y: pillCenterY - 13)
        }
        .frame(height: pillHeight, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
