import SwiftUI

struct TimelineView: View {
    @StateObject private var vm = DayScheduleViewModel()

    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    
    /// 0 = front card fully covers. 1 = fully revealed (collapsed to bottom pill).
    @State private var revealProgress: CGFloat = 0
    
    // Theme colors
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let darkerBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)
    
    private var lineX: CGFloat {
        vm.timeColumnWidth + 10 + 22 - 0.75
    }
    
    private var isRevealed: Bool { revealProgress > 0.5 }
    
    /// The 7 dates visible in the calendar strip, respecting the device locale's firstWeekday.
    /// This ensures column 0 = leftmost day in the strip, column 6 = rightmost.
    private var weekDates: [Date] {
        let cal = vm.calendar
        let selected = cal.startOfDay(for: vm.selectedDate)
        
        // Find what weekday selectedDate is (1=Sun, 2=Mon, ..., 7=Sat)
        let selectedWeekday = cal.component(.weekday, from: selected)
        let firstWeekday = cal.firstWeekday // Respects locale (e.g. 7=Sat, 2=Mon, 1=Sun)
        
        // How many days back from selected to reach the start of this week
        var diff = selectedWeekday - firstWeekday
        if diff < 0 { diff += 7 }
        
        // The first day of this week
        guard let weekStart = cal.date(byAdding: .day, value: -diff, to: selected) else { return [] }
        
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                
                // ── MAIN LAYOUT ──
                VStack(spacing: 0) {
                    
                    // ═══════════════════════════════════
                    // SHARED HEADER — pinned at top
                    // ═══════════════════════════════════
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
                    
                    // ═══════════════════════════════════
                    // SHARED CALENDAR STRIP — pinned
                    // ═══════════════════════════════════
                    HorizontalCalendarView(selectedDate: $vm.selectedDate, vm: vm)
                        .padding(.bottom, 10)
                    
                    // ═══════════════════════════════════
                    // TWO-PAGE STACK
                    // ═══════════════════════════════════
                    GeometryReader { geo in
                        let totalH = geo.size.height
                        let collapsedCardH: CGFloat = 130
                        let maxOffset = totalH - collapsedCardH
                        let currentOffset = revealProgress * maxOffset
                        
                        ZStack(alignment: .top) {
                            
                            // ── BACK PAGE: Week Overview ──
                            WeekOverviewView(vm: vm, weekDates: weekDates)
                                .opacity(revealProgress > 0.05 ? 1 : 0)
                                .animation(.easeOut(duration: 0.15), value: revealProgress > 0.05)
                            
                            // ── FRONT CARD (draggable, collapses to pill) ──
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
                                        let newProgress: CGFloat
                                        if delta > 0 {
                                            newProgress = revealProgress + delta / maxOffset
                                        } else {
                                            newProgress = revealProgress + delta / maxOffset
                                        }
                                        revealProgress = min(1, max(0, newProgress))
                                    }
                                    .onEnded { value in
                                        let velocity = value.predictedEndTranslation.height
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
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
                .background(darkerBackground.ignoresSafeArea())
                
                // ═══════════════════════════════════
                // "+" BUTTON — always visible
                // ═══════════════════════════════════
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
        }
        .sheet(isPresented: $showingAdd) {
            AddEditTaskView(viewModel: vm)
        }
        .sheet(item: $editingTask) { task in
            AddEditTaskView(viewModel: vm, taskToEdit: task)
        }
    }
    
    // MARK: - Day Timeline (full front card content)
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
    
    // MARK: - Collapsed Task Pill (front card when fully revealed)
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
