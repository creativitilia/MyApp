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
        isEyeOverlap ? 8 : 6
    }
    
    // The actual pill capsule height
    private var pillHeight: CGFloat {
        max(height, pillWidth)
    }
    
    // The vertical center of the pill — where text should anchor
    private var pillCenterY: CGFloat {
        pillHeight / 2
    }
    
    var body: some View {
        // Use .top alignment so we can manually position text at pill center
        HStack(alignment: .top, spacing: 16) {
            
            // 1. The Unified Pill Shape
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
            
            // 2. Text Content — anchored to the pill's vertical center
            VStack(alignment: .leading, spacing: 3) {
                let endTime = task.startTime.addingTimeInterval(task.duration)
                Text("\(task.startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened)) (\(Int(task.durationMinutes)) min)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(task.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: false, vertical: true) // Never compress text vertically
            // Offset so the text block's center aligns with the pill's center.
            // Text block is ~38pt tall (caption 14 + spacing 3 + headline 18 ≈ 35-38pt).
            // So offset = pillCenter - (textHeight / 2)
            .offset(y: pillCenterY - 19)
            
            Spacer(minLength: 0)
            
            // 3. Completion Checkbox — also at pill center
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
            .offset(y: pillCenterY - 13) // Center the 26pt checkbox on the pill center
        }
        .frame(height: pillHeight, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
