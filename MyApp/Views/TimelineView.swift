import SwiftUI

// MARK: - Horizontal-pass-through ScrollView
final class HorizontalPassthroughScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              pan === self.panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = pan.velocity(in: self)
        if abs(velocity.x) > abs(velocity.y) { return false }
        return true
    }
}

struct PageFriendlyScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    
    func makeUIView(context: Context) -> HorizontalPassthroughScrollView {
        let sv = HorizontalPassthroughScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.alwaysBounceHorizontal = false
        sv.backgroundColor = .clear
        let hc = UIHostingController(rootView: content)
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        sv.addSubview(hc.view)
        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: sv.contentLayoutGuide.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: sv.contentLayoutGuide.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: sv.contentLayoutGuide.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: sv.contentLayoutGuide.bottomAnchor),
            hc.view.widthAnchor.constraint(equalTo: sv.frameLayoutGuide.widthAnchor),
        ])
        context.coordinator.hostingController = hc
        return sv
    }
    
    func updateUIView(_ sv: HorizontalPassthroughScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var hostingController: UIHostingController<Content>? }
}


// MARK: - TimelineView
struct TimelineView: View {
    @StateObject private var vm = DayScheduleViewModel()
    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    @State private var currentWeekOffset: Int = 0
    @State private var revealProgress: CGFloat = 0
    
    private let weekRange = -52...52
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let darkerBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $currentWeekOffset) {
                ForEach(weekRange, id: \.self) { offset in
                    WeekPageView(
                        vm: vm, weekOffset: offset,
                        showingAdd: $showingAdd,
                        editingTask: $editingTask,
                        revealProgress: $revealProgress
                    ).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(darkerBackground.ignoresSafeArea())
            .onChange(of: currentWeekOffset) { _, newOffset in
                let todayMonday = vm.mondayOf(date: Date())
                if let newMonday = vm.calendar.date(byAdding: .weekOfYear, value: newOffset, to: todayMonday) {
                    let wd = vm.calendar.component(.weekday, from: vm.selectedDate)
                    let wdOff = (wd + 5) % 7
                    vm.selectedDate = vm.calendar.date(byAdding: .day, value: wdOff, to: newMonday) ?? newMonday
                }
            }
            
            Button(action: { showingAdd = true }) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(themePink)
                    .clipShape(Circle())
                    .shadow(color: themePink.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20).padding(.bottom, 30).zIndex(999)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAdd) { AddEditTaskView(viewModel: vm) }
        .sheet(item: $editingTask) { task in AddEditTaskView(viewModel: vm, taskToEdit: task) }
    }
}


// MARK: - WeekPageView
struct WeekPageView: View {
    @ObservedObject var vm: DayScheduleViewModel
    let weekOffset: Int
    @Binding var showingAdd: Bool
    @Binding var editingTask: TaskItem?
    @Binding var revealProgress: CGFloat
    
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let darkerBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)
    
    // New pill width = 70, so pill center X = leading padding(16) + pillWidth(70)/2 = 51
    private let pillWidth: CGFloat = 70
    private let timeColumnWidth: CGFloat = 55
    private let contentLeading: CGFloat = 16
    
    private var isRevealed: Bool { revealProgress > 0.5 }
    
    private var weekDates: [Date] {
        let todayMonday = vm.mondayOf(date: Date())
        guard let pageMonday = vm.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: todayMonday) else { return [] }
        return vm.weekDates(for: pageMonday)
    }
    
    private var isCurrentPage: Bool {
        let selectedMonday = vm.mondayOf(date: vm.selectedDate)
        let todayMonday = vm.mondayOf(date: Date())
        guard let pageMonday = vm.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: todayMonday) else { return false }
        return vm.calendar.isDate(selectedMonday, inSameDayAs: pageMonday)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isCurrentPage { headerView } else { headerViewForPage }
            
            HorizontalCalendarView(selectedDate: $vm.selectedDate, vm: vm, weekDates: weekDates)
                .padding(.bottom, 10)
            
            GeometryReader { geo in
                let totalH = geo.size.height
                let collapsedCardH: CGFloat = 130
                let maxOffset = totalH - collapsedCardH
                let currentOffset = revealProgress * maxOffset
                
                ZStack(alignment: .top) {
                    WeekOverviewView(vm: vm, weekDates: weekDates)
                        .opacity(revealProgress > 0.05 ? 1 : 0)
                        .animation(.easeOut(duration: 0.2), value: revealProgress > 0.05)
                    
                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .padding(.top, 10).padding(.bottom, 8)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 8)
                                    .onChanged { v in
                                        revealProgress = min(1, max(0, revealProgress + v.translation.height / maxOffset))
                                    }
                                    .onEnded { v in
                                        let vel = v.predictedEndTranslation.height
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            if v.translation.height > 80 || vel > 200 { revealProgress = 1 }
                                            else if v.translation.height < -60 || vel < -200 { revealProgress = 0 }
                                            else { revealProgress = revealProgress > 0.5 ? 1 : 0 }
                                        }
                                    }
                            )
                        
                        if revealProgress < 0.85 {
                            dayTimelineContent
                        } else {
                            collapsedTaskPill
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(darkBackground)
                    .clipShape(RoundedRectangle(cornerRadius: revealProgress > 0.02 ? 20 : 0))
                    .shadow(color: .black.opacity(revealProgress > 0.02 ? 0.5 : 0), radius: 20, y: -5)
                    .offset(y: currentOffset)
                }
            }
        }
        .background(darkerBackground)
    }
    
    // MARK: - Headers
    private var headerView: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isRevealed {
                Text(vm.selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 28, weight: .bold)).foregroundColor(.white).transition(.opacity)
            } else {
                Text(vm.selectedDate.formatted(.dateTime.day().month(.wide)))
                    .font(.system(size: 28, weight: .bold)).foregroundColor(.white).transition(.opacity)
            }
            Text(vm.selectedDate.formatted(.dateTime.year()))
                .font(.system(size: 28, weight: .bold)).foregroundColor(themePink)
            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .bold)).foregroundColor(themePink).padding(.bottom, 4)
            Spacer()
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.25), value: isRevealed)
    }
    
    private var headerViewForPage: some View {
        let d = weekDates.first ?? Date()
        return HStack(alignment: .bottom, spacing: 6) {
            Text(d.formatted(.dateTime.month(.wide)))
                .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
            Text(d.formatted(.dateTime.year()))
                .font(.system(size: 28, weight: .bold)).foregroundColor(themePink)
            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .bold)).foregroundColor(themePink).padding(.bottom, 4)
            Spacer()
        }
        .padding(.horizontal).padding(.top, 10).padding(.bottom, 8)
    }
    
    // MARK: - Day Timeline (Structured-Style)
    private var dayTimelineContent: some View {
        let sortedTasks = vm.tasks.sorted { $0.startTime < $1.startTime }
        
        return Group {
            if sortedTasks.isEmpty {
                VStack {
                    Spacer()
                    Text("No tasks for this day")
                        .font(.subheadline).foregroundColor(.gray.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PageFriendlyScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sortedTasks.enumerated()), id: \.element.id) { index, task in
                            // ── TASK ROW: time labels on left, pill+text on right ──
                            taskRow(task: task)
                                .padding(.top, index == 0 ? 4 : 10)
                            
                            // ── BREAK between tasks ──
                            if index < sortedTasks.count - 1 {
                                let nextTask = sortedTasks[index + 1]
                                let taskEnd = task.startTime.addingTimeInterval(task.duration)
                                let gapMinutes = Int(nextTask.startTime.timeIntervalSince(taskEnd) / 60)
                                
                                if gapMinutes > 0 {
                                    breakSection(
                                        fromTask: task,
                                        toTask: nextTask,
                                        endTime: taskEnd,
                                        startTime: nextTask.startTime,
                                        index: index
                                    )
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    // MARK: - Task Row (time column + pill + text)
    private func taskRow(task: TaskItem) -> some View {
        let taskPillHeight = max(pillWidth, CGFloat(task.durationMinutes) * 1.5)
        let endTime = task.startTime.addingTimeInterval(task.duration)
        
        return HStack(alignment: .top, spacing: 0) {
            // Left time column — start time at top, end time at bottom
            VStack(alignment: .trailing, spacing: 0) {
                Text(vm.timeString(for: task.startTime))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
                
                Spacer(minLength: 0)
                
                Text(vm.timeString(for: endTime))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .frame(width: timeColumnWidth, height: taskPillHeight)
            .padding(.leading, 8)
            
            // Pill + text + checkbox
            TaskBlockView(
                task: task,
                height: taskPillHeight,
                isEyeOverlap: false,
                onTap: { editingTask = task },
                onToggleComplete: { vm.toggleCompletion(for: task) }
            )
            .padding(.trailing, 16)
        }
    }
    
    // MARK: - Break Section (gradient dashed line + message)
    private func breakSection(fromTask: TaskItem, toTask: TaskItem, endTime: Date, startTime: Date, index: Int) -> some View {
        let lineX = 8 + timeColumnWidth + pillWidth / 2  // align with pill center
        
        return VStack(spacing: 0) {
            // Gradient dashed line between tasks
            ZStack(alignment: .leading) {
                // The dashed gradient line
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: lineX - 1.5)
                    
                    DashedGradientLine(
                        fromColor: fromTask.color,
                        toColor: toTask.color
                    )
                    .frame(width: 3, height: 40)
                    
                    Spacer()
                }
                
                // Break message next to the line
                HStack(spacing: 6) {
                    Spacer()
                        .frame(width: lineX + 14)
                    
                    Image(systemName: "zzz")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(breakMessage(for: index))
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                        .italic()
                }
            }
            .frame(height: 40)
        }
        .padding(.vertical, 4)
    }
    
    private func breakMessage(for index: Int) -> String {
        let messages = [
            "A well-deserved break.",
            "Time to recharge.",
            "Rest and reset.",
            "Pause and breathe."
        ]
        return messages[index % messages.count]
    }
    
    // MARK: - Collapsed Task Pill
    @ViewBuilder
    private var collapsedTaskPill: some View {
        let now = Date()
        let sortedTasks = vm.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
        
        let activeTask: TaskItem? = sortedTasks.first { task in
            let end = task.startTime.addingTimeInterval(task.duration)
            return end > now
        } ?? sortedTasks.last
        
        if let task = activeTask {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(task.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: task.icon ?? "doc.text.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(task.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    let endTime = task.startTime.addingTimeInterval(task.duration)
                    let durText: String = {
                        let mins = Int(task.durationMinutes)
                        if mins >= 60 {
                            let h = mins / 60; let m = mins % 60
                            return m > 0 ? "\(h) hr, \(m) min" : "\(h) hr"
                        }
                        return "\(mins) min"
                    }()
                    
                    if task.startTime <= now && endTime > now {
                        let rem = max(0, Int(endTime.timeIntervalSince(now) / 60))
                        Text("\(rem)m remaining")
                            .font(.caption).foregroundColor(.gray)
                    } else {
                        Text("\(task.startTime.formatted(date: .omitted, time: .shortened)) – \(endTime.formatted(date: .omitted, time: .shortened)) (\(durText))")
                            .font(.caption).foregroundColor(.gray)
                    }
                    Text(task.title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: { vm.toggleCompletion(for: task) }) {
                    Circle()
                        .strokeBorder(task.color, lineWidth: 2.5)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .onTapGesture { editingTask = task }
        } else {
            Text("No upcoming tasks")
                .font(.subheadline).foregroundColor(.gray)
                .padding(.vertical, 20)
        }
        
        Spacer(minLength: 0)
    }
}


// MARK: - Dashed Gradient Line Shape
struct DashedGradientLine: View {
    let fromColor: Color
    let toColor: Color
    
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let dashHeight: CGFloat = 6
            let gapHeight: CGFloat = 5
            let step = dashHeight + gapHeight
            let count = Int(h / step) + 1
            
            Canvas { context, size in
                for i in 0..<count {
                    let y = CGFloat(i) * step
                    if y + dashHeight > h { break }
                    
                    let progress = h > 0 ? y / h : 0
                    let rect = CGRect(
                        x: (size.width - 3) / 2,
                        y: y,
                        width: 3,
                        height: min(dashHeight, h - y)
                    )
                    
                    let blendedColor = blendColor(from: fromColor, to: toColor, progress: progress)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1.5),
                        with: .color(blendedColor)
                    )
                }
            }
        }
    }
    
    private func blendColor(from: Color, to: Color, progress: CGFloat) -> Color {
        // Simple linear interpolation via opacity layering
        let p = min(1, max(0, progress))
        return Color(
            red: lerp(from: from.components.red, to: to.components.red, t: p),
            green: lerp(from: from.components.green, to: to.components.green, t: p),
            blue: lerp(from: from.components.blue, to: to.components.blue, t: p)
        )
    }
    
    private func lerp(from: Double, to: Double, t: Double) -> Double {
        from + (to - from) * t
    }
}

// Helper to extract Color components
extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
