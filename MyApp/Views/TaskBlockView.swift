import SwiftUI

struct TaskBlockView: View {
    let task: TaskItem
    let height: CGFloat
    let isEyeOverlap: Bool          // NEW: controls eye-junction visual treatment
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    
    let pillWidth: CGFloat = 48
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    
    // Stroke width adapts: thicker for eye overlaps to make the junction pronounced
    private var strokeWidth: CGFloat {
        isEyeOverlap ? 8 : 6
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            
            // 1. The Unified Pill Shape
            ZStack(alignment: .center) {
                Capsule()
                    .fill(task.isCompleted ? task.color.opacity(0.3) : task.color)
                    .frame(width: pillWidth, height: max(height, pillWidth))
                
                Image(systemName: task.isCompleted ? "checkmark" : (task.icon ?? "doc.text.fill"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(task.isCompleted ? task.color : .white)
            }
            // THE CUTOUT TRICK: This thick dark stroke matches the timeline background,
            // naturally erasing the dotted line and any pills underneath it!
            // For eye overlaps, a thicker stroke creates a more pronounced junction.
            .overlay(
                Capsule()
                    .stroke(darkBackground, lineWidth: strokeWidth)
            )
            // Subtle colored glow for eye overlaps — creates the soft color fringe
            // visible at the edges of the eye junction in the inspiration images
            .shadow(
                color: isEyeOverlap ? task.color.opacity(0.4) : .clear,
                radius: isEyeOverlap ? 4 : 0,
                x: 0, y: 0
            )
            .frame(width: pillWidth, height: max(height, pillWidth), alignment: .center)
            
            // 2. Text Content
            VStack(alignment: .leading, spacing: 4) {
                let endTime = task.startTime.addingTimeInterval(task.duration)
                HStack(spacing: 4) {
                    Text("\(task.startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))")
                    Text("(\(Int(task.durationMinutes)) min)")
                }
                .font(.caption)
                .foregroundColor(.gray)
                
                Text(task.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                    .strikethrough(task.isCompleted)
            }
            
            Spacer(minLength: 0)
            
            // 3. Completion Checkbox — uses task color ring to match inspo images
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
        }
        .frame(height: max(height, pillWidth), alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
