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
    
    // MARK: - Day Timeline (Structured-Style Sequential List)
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
                            // ── TIME LABEL for task start ──
                            HStack(spacing: 0) {
                                Text(vm.timeString(for: task.startTime))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .frame(width: vm.timeColumnWidth, alignment: .leading)
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .padding(.bottom, 2)
                            
                            // ── TASK BLOCK ──
                            HStack(alignment: .top, spacing: 0) {
                                // Colored line on the left (in the time column area)
                                ZStack {
                                    // Dashed line through the time column
                                    Path { p in
                                        let x = vm.timeColumnWidth + 2
                                        p.move(to: CGPoint(x: x, y: 0))
                                        p.addLine(to: CGPoint(x: x, y: max(48, task.durationMinutes > 30 ? 100 : 60)))
                                    }
                                    .stroke(task.color, style: StrokeStyle(lineWidth: 2.5))
                                }
                                .frame(width: vm.timeColumnWidth + 4, height: 0)
                                .opacity(0) // hide — the pill block handles visuals
                                
                                TaskBlockView(
                                    task: task,
                                    height: max(48, CGFloat(task.durationMinutes) * 1.2),
                                    isEyeOverlap: false,
                                    onTap: { editingTask = task },
                                    onToggleComplete: { vm.toggleCompletion(for: task) }
                                )
                            }
                            .padding(.leading, 8)
                            
                            // ── GAP / BREAK between tasks ──
                            if index < sortedTasks.count - 1 {
                                let nextTask = sortedTasks[index + 1]
                                let taskEnd = task.startTime.addingTimeInterval(task.duration)
                                let gapMinutes = Int(nextTask.startTime.timeIntervalSince(taskEnd) / 60)
                                
                                if gapMinutes > 0 {
                                    // End time label
                                    HStack(spacing: 0) {
                                        Text(vm.timeString(for: taskEnd))
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.gray.opacity(0.6))
                                            .frame(width: vm.timeColumnWidth, alignment: .leading)
                                        
                                        // Dashed break line + message
                                        VStack(spacing: 6) {
                                            HStack(spacing: 8) {
                                                Path { p in
                                                    p.move(to: CGPoint(x: 0, y: 12))
                                                    p.addLine(to: CGPoint(x: 0, y: max(40, CGFloat(min(gapMinutes, 120)) * 0.5)))
                                                }
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [task.color.opacity(0.4), nextTask.color.opacity(0.4)],
                                                        startPoint: .top, endPoint: .bottom
                                                    ),
                                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                                                )
                                                .frame(width: 2)
                                                
                                                let breakMessages = [
                                                    "A well-deserved break.",
                                                    "Time to recharge.",
                                                    "Rest and reset.",
                                                    "Pause and breathe."
                                                ]
                                                
                                                HStack(spacing: 4) {
                                                    Text("💤")
                                                        .font(.caption)
                                                    Text(breakMessages[index % breakMessages.count])
                                                        .font(.caption)
                                                        .foregroundColor(.gray.opacity(0.5))
                                                        .italic()
                                                }
                                                .padding(.top, 6)
                                                
                                                Spacer()
                                            }
                                            .padding(.leading, 22)
                                        }
                                    }
                                    .padding(.leading, 8)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        // ── FINAL END TIME ──
                        if let lastTask = sortedTasks.last {
                            let endTime = lastTask.startTime.addingTimeInterval(lastTask.duration)
                            HStack(spacing: 0) {
                                Text(vm.timeString(for: endTime))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .frame(width: vm.timeColumnWidth, alignment: .leading)
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .padding(.top, 4)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    // MARK: - Collapsed Task Pill (fixed: show next or last task, not just "no upcoming")
    @ViewBuilder
    private var collapsedTaskPill: some View {
        let now = Date()
        let sortedTasks = vm.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
        
        // Find next active/upcoming task, or fall back to the last task of the day
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
                        .strokeBorder(task.color.opacity(0.5), lineWidth: 2)
                        .frame(width: 28, height: 28)
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
