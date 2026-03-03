import SwiftUI

// MARK: - Horizontal-pass-through ScrollView
final class HorizontalPassthroughScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              pan === self.panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = pan.velocity(in: self)
        if abs(velocity.x) > abs(velocity.y) {
            return false
        }
        return true
    }
}

struct PageFriendlyScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> HorizontalPassthroughScrollView {
        let scrollView = HorizontalPassthroughScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.backgroundColor = .clear
        
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(hostingController.view)
        
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        
        context.coordinator.hostingController = hostingController
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: HorizontalPassthroughScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}


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
                        vm: vm,
                        weekOffset: offset,
                        showingAdd: $showingAdd,
                        editingTask: $editingTask,
                        revealProgress: $revealProgress
                    )
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(darkerBackground.ignoresSafeArea())
            .onChange(of: currentWeekOffset) { _, newOffset in
                let today = Date()
                let todayMonday = vm.mondayOf(date: today)
                if let newMonday = vm.calendar.date(byAdding: .weekOfYear, value: newOffset, to: todayMonday) {
                    let currentWeekday = vm.calendar.component(.weekday, from: vm.selectedDate)
                    let wdOffset = (currentWeekday + 5) % 7
                    if let newDate = vm.calendar.date(byAdding: .day, value: wdOffset, to: newMonday) {
                        vm.selectedDate = newDate
                    } else {
                        vm.selectedDate = newMonday
                    }
                }
            }
            
            // "+" BUTTON
            Button(action: { showingAdd = true }) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(themePink)
                    .clipShape(Circle())
                    .shadow(color: themePink.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 30)
            .zIndex(999)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAdd) {
            AddEditTaskView(viewModel: vm)
        }
        .sheet(item: $editingTask) { task in
            AddEditTaskView(viewModel: vm, taskToEdit: task)
        }
    }
}

// MARK: - One Full Week Page
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
            
            if isCurrentPage {
                headerView
            } else {
                headerViewForPage
            }
            
            HorizontalCalendarView(
                selectedDate: $vm.selectedDate,
                vm: vm,
                weekDates: weekDates
            )
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
                            .padding(.top, 10)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 8)
                                    .onChanged { value in
                                        let delta = value.translation.height
                                        let newProgress = revealProgress + delta / maxOffset
                                        revealProgress = min(1, max(0, newProgress))
                                    }
                                    .onEnded { value in
                                        let velocity = value.predictedEndTranslation.height
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            if value.translation.height > 80 || velocity > 200 {
                                                revealProgress = 1
                                            } else if value.translation.height < -60 || velocity < -200 {
                                                revealProgress = 0
                                            } else {
                                                revealProgress = revealProgress > 0.5 ? 1 : 0
                                            }
                                        }
                                    }
                            )
                        
                        if revealProgress < 0.85 {
                            dayTimelineContent(availableHeight: totalH - 44)
                        } else {
                            collapsedTaskPill
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(darkBackground)
                    .clipShape(
                        RoundedRectangle(cornerRadius: revealProgress > 0.02 ? 20 : 0)
                    )
                    .shadow(
                        color: .black.opacity(revealProgress > 0.02 ? 0.5 : 0),
                        radius: 20, y: -5
                    )
                    .offset(y: currentOffset)
                }
            }
        }
        .background(darkerBackground)
    }
    
    // MARK: - Header for Active Page
    private var headerView: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isRevealed {
                Text(vm.selectedDate.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.opacity)
            } else {
                Text(vm.selectedDate.formatted(.dateTime.day().month(.wide)))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.opacity)
            }
            
            Text(vm.selectedDate.formatted(.dateTime.year()))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(themePink)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(themePink)
                .padding(.bottom, 4)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.25), value: isRevealed)
    }
    
    // MARK: - Header for Non-Active Pages
    private var headerViewForPage: some View {
        let pageDate = weekDates.first ?? Date()
        return HStack(alignment: .bottom, spacing: 6) {
            Text(pageDate.formatted(.dateTime.month(.wide)))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(pageDate.formatted(.dateTime.year()))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(themePink)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(themePink)
                .padding(.bottom, 4)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
    
    // MARK: - Day Timeline Content (ADAPTIVE)
    private func dayTimelineContent(availableHeight: CGFloat) -> some View {
        let hasTasks = !vm.tasks.isEmpty
        let ppm = vm.adaptivePixelsPerMinute(availableHeight: availableHeight)
        let lineX = vm.timeColumnWidth + 10 + 22 - CGFloat(0.75)
        
        return Group {
            if !hasTasks {
                // ── NO TASKS: empty state ──
                VStack {
                    Spacer()
                    Text("No tasks for this day")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PageFriendlyScrollView {
                    ZStack(alignment: .topLeading) {
                        // Invisible spacer for height
                        Color.clear
                            .frame(height: vm.adaptiveTimelineHeight(ppm: ppm))
                        
                        // Adaptive time column
                        TimeColumnView(vm: vm, adaptivePPM: ppm)
                        
                        // Dashed center line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0))
                            path.addLine(to: CGPoint(x: 0, y: vm.adaptiveTimelineHeight(ppm: ppm)))
                        }
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .offset(x: lineX)
                        
                        // Task color lines
                        ForEach(vm.adaptiveLayoutAttributes(ppm: ppm), id: \.task.id) { layout in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: layout.yPos))
                                path.addLine(to: CGPoint(x: 0, y: layout.yPos + layout.height))
                            }
                            .stroke(layout.task.color, style: StrokeStyle(lineWidth: 2.5))
                            .offset(x: lineX)
                            .zIndex(-1)
                        }
                        
                        // Task blocks
                        ForEach(vm.adaptiveLayoutAttributes(ppm: ppm), id: \.task.id) { layout in
                            if layout.showOverlapWarning {
                                HStack(spacing: 0) {
                                    Text("Tasks are ")
                                        .foregroundColor(.gray)
                                    Text("overlapping")
                                        .foregroundColor(themePink)
                                }
                                .font(.caption.weight(.medium))
                                .offset(x: vm.timeColumnWidth + 10 + vm.pillWidth + 16,
                                        y: layout.warningYPos)
                                .zIndex(100)
                            }
                            
                            HStack {
                                Spacer().frame(width: vm.timeColumnWidth + 10)
                                TaskBlockView(
                                    task: layout.task,
                                    height: layout.height,
                                    isEyeOverlap: layout.isEyeOverlap,
                                    onTap: { editingTask = layout.task },
                                    onToggleComplete: { vm.toggleCompletion(for: layout.task) }
                                )
                            }
                            .offset(y: layout.yPos)
                            .zIndex(layout.zIndex)
                        }
                    }
                    .frame(height: vm.adaptiveTimelineHeight(ppm: ppm) + 60, alignment: .top)
                    .padding(.vertical, 20)
                }
            }
        }
    }
    
    // MARK: - Collapsed Task Pill
    @ViewBuilder
    private var collapsedTaskPill: some View {
        let now = Date()
        let active = vm.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
            .first { task in
                let end = task.startTime.addingTimeInterval(task.duration)
                return end > now
            }
        
        if let task = active {
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
                    if task.startTime <= now {
                        let rem = max(0, Int(endTime.timeIntervalSince(now) / 60))
                        Text("\(rem)m remaining")
                            .font(.caption).foregroundColor(.gray)
                    } else {
                        Text(task.startTime.formatted(date: .omitted, time: .shortened))
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
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .onTapGesture { editingTask = task }
        } else {
            Text("No upcoming tasks")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.vertical, 20)
        }
        
        Spacer(minLength: 0)
    }
}
