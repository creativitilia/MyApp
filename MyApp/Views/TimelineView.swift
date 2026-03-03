import SwiftUI

struct TimelineView: View {
    @StateObject private var vm = DayScheduleViewModel()
    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    
    /// Which week page we're on, as an offset from "this week" (0 = current week)
    @State private var currentWeekOffset: Int = 0
    
    /// Only keep a small window of pages loaded for performance
    private var weekRange: ClosedRange<Int> {
        (currentWeekOffset - 4)...(currentWeekOffset + 4)
    }
    
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let darkerBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $currentWeekOffset) {
                ForEach(Array(weekRange.lowerBound...weekRange.upperBound), id: \.self) { offset in
                    WeekPageView(
                        vm: vm,
                        weekOffset: offset,
                        showingAdd: $showingAdd,
                        editingTask: $editingTask
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
                        withAnimation(.easeInOut(duration: 0.25)) {
                            vm.selectedDate = newDate
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            vm.selectedDate = newMonday
                        }
                    }
                }
            }
            
            // "+" BUTTON — always on top
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
    
    @State private var revealProgress: CGFloat = 0
    
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let darkerBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)
    
    private var lineX: CGFloat {
        vm.timeColumnWidth + 10 + 22 - 0.75
    }
    private var isRevealed: Bool { revealProgress > 0.5 }
    
    /// The 7 dates (Mon→Sun) for THIS week page
    private var weekDates: [Date] {
        let todayMonday = vm.mondayOf(date: Date())
        guard let pageMonday = vm.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: todayMonday) else { return [] }
        return vm.weekDates(for: pageMonday)
    }
    
    /// Whether selectedDate belongs to this page's week
    private var isCurrentPage: Bool {
        let selectedMonday = vm.mondayOf(date: vm.selectedDate)
        let todayMonday = vm.mondayOf(date: Date())
        guard let pageMonday = vm.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: todayMonday) else { return false }
        return vm.calendar.isDate(selectedMonday, inSameDayAs: pageMonday)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // ═══════════════════════════════════
            // HEADER — only shown on current page to avoid duplicate headers during swipe
            // ═══════════════════════════════════
            if isCurrentPage {
                headerView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Show the week's month/year for non-active pages
                headerViewForPage
                    .transition(.opacity)
            }
            
            // ═══════════════════════════════════
            // CALENDAR STRIP (fixed 7-day, Mon→Sun)
            // ═══════════════════════════════════
            HorizontalCalendarView(
                selectedDate: $vm.selectedDate,
                vm: vm,
                weekDates: weekDates
            )
            .padding(.bottom, 10)
            
            // ═══════════════════════════════════
            // TWO-LAYER STACK
            // ═══════════════════════════════════
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
                        
                        if revealProgress < 0.85 {
                            dayTimelineContent
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
    
    // MARK: - Header for Non-Active Pages (shows that page's month)
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
    
    // MARK: - Day Timeline Content
    private var dayTimelineContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Color.clear
                                .frame(height: 60 * vm.pixelsPerMinute)
                                .id(hour)
                        }
                    }
                    
                    TimeColumnView(vm: vm)
                    
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: vm.timelineHeight()))
                    }
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(x: lineX)
                    
                    ForEach(vm.layoutAttributes, id: \.task.id) { layout in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: layout.yPos))
                            path.addLine(to: CGPoint(x: 0, y: layout.yPos + layout.height))
                        }
                        .stroke(layout.task.color, style: StrokeStyle(lineWidth: 2.5))
                        .offset(x: lineX)
                        .zIndex(-1)
                    }
                    
                    if vm.calendar.isDate(vm.selectedDate, inSameDayAs: Date()) {
                        let currentY = vm.yPosition(for: vm.currentTime)
                        Text(vm.currentTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: vm.timeColumnWidth, alignment: .trailing)
                            .offset(y: currentY - 7)
                            .animation(.linear(duration: 1.0), value: currentY)
                            .zIndex(50)
                    }
                    
                    ForEach(vm.layoutAttributes, id: \.task.id) { layout in
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
                .frame(height: vm.timelineHeight() + 100, alignment: .top)
                .padding(.vertical, 20)
            }
            .onAppear { scrollToCurrentHour(using: scrollProxy) }
            .onChange(of: vm.selectedDate) { scrollToCurrentHour(using: scrollProxy) }
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
    
    // MARK: - Scroll Helper
    private func scrollToCurrentHour(using proxy: ScrollViewProxy) {
        if vm.calendar.isDate(vm.selectedDate, inSameDayAs: Date()) {
            let currentHour = vm.calendar.component(.hour, from: vm.currentTime)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    proxy.scrollTo(currentHour, anchor: .center)
                }
            }
        }
    }
}
