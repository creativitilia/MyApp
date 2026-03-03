import SwiftUI

struct TimelineView: View {
    @StateObject private var vm = DayScheduleViewModel()

    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    
    /// How far the front card has slid down (0 = fully covering)
    @State private var cardOffset: CGFloat = 0
    
    // Theme colors
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let darkerBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)
    
    private var lineX: CGFloat {
        vm.timeColumnWidth + 10 + 22 - 0.75
    }
    
    /// Whether the back page (week overview) is currently revealed
    private var isRevealed: Bool { cardOffset > 100 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                
                // ── MAIN CONTENT ──
                VStack(spacing: 0) {
                    
                    // ═══════════════════════════════════════════
                    // SHARED HEADER — pinned, never moves
                    // ═══════════════════════════════════════════
                    HStack(alignment: .bottom, spacing: 6) {
                        // Animate between "3 March" and "March" based on reveal state
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
                    
                    // ═══════════════════════════════════════════
                    // SHARED CALENDAR STRIP — pinned, never moves
                    // ═══════════════════════════════════════════
                    HorizontalCalendarView(selectedDate: $vm.selectedDate, vm: vm)
                        .padding(.bottom, 15)
                    
                    // ═══════════════════════════════════════════
                    // TWO-PAGE STACK
                    // Back: Week overview (always rendered)
                    // Front: Day timeline card (slides down)
                    // ═══════════════════════════════════════════
                    GeometryReader { geo in
                        let maxOffset = geo.size.height * 0.7
                        
                        ZStack(alignment: .top) {
                            
                            // ── BACK PAGE ──
                            VStack(spacing: 0) {
                                WeekOverviewView(vm: vm)
                                
                                Spacer(minLength: 0)
                                
                                activeTaskCard
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(cardOffset > 10 ? 1 : 0)
                            .animation(.easeOut(duration: 0.2), value: cardOffset > 10)
                            
                            // ── FRONT CARD (draggable) ──
                            VStack(spacing: 0) {
                                // Drag handle
                                Capsule()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 40, height: 5)
                                    .padding(.top, 10)
                                    .padding(.bottom, 8)
                                
                                // Scrollable day timeline
                                dayTimelineContent
                            }
                            .background(darkBackground)
                            .clipShape(
                                RoundedRectangle(cornerRadius: cardOffset > 5 ? 20 : 0)
                            )
                            .shadow(
                                color: .black.opacity(cardOffset > 5 ? 0.5 : 0),
                                radius: 20, y: -5
                            )
                            .offset(y: cardOffset)
                            .gesture(
                                DragGesture(minimumDistance: 8)
                                    .onChanged { value in
                                        let t = value.translation.height
                                        if cardOffset == 0 && t > 0 {
                                            // Pulling down from closed
                                            cardOffset = t
                                        } else if cardOffset > 0 {
                                            // Already open or mid-drag
                                            let newOffset = cardOffset + (t > 0 ? t * 0.5 : t)
                                            cardOffset = max(0, min(newOffset, maxOffset))
                                        }
                                    }
                                    .onEnded { value in
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                            if value.translation.height > 120
                                                || value.predictedEndTranslation.height > 250 {
                                                cardOffset = maxOffset
                                            } else {
                                                cardOffset = 0
                                            }
                                        }
                                    }
                            )
                        }
                    }
                }
                .background(darkerBackground.ignoresSafeArea())
                
                // ═══════════════════════════════════════════
                // FIX #3: "+" BUTTON — global overlay, always visible
                // ═══════════════════════════════════════════
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
    
    // MARK: - Day Timeline (front card body)
    private var dayTimelineContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // INVISIBLE HOUR ANCHORS
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Color.clear
                                .frame(height: 60 * vm.pixelsPerMinute)
                                .id(hour)
                        }
                    }
                    
                    // A. Time Labels
                    TimeColumnView(vm: vm)
                    
                    // B. Base dashed line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: vm.timelineHeight()))
                    }
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .offset(x: lineX)
                    
                    // Colored segments
                    ForEach(vm.layoutAttributes, id: \.task.id) { layout in
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: layout.yPos))
                            path.addLine(to: CGPoint(x: 0, y: layout.yPos + layout.height))
                        }
                        .stroke(layout.task.color, style: StrokeStyle(lineWidth: 2.5))
                        .offset(x: lineX)
                        .zIndex(-1)
                    }
                    
                    // C. Current Time
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
                    
                    // D. Task Layouts
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
    
    // MARK: - Active Task Card (bottom of back page)
    @ViewBuilder
    private var activeTaskCard: some View {
        let now = Date()
        let active = vm.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.startTime < $1.startTime }
            .first { task in
                let end = task.startTime.addingTimeInterval(task.duration)
                return end > now
            }
        
        if let task = active {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(task.color.opacity(0.2))
                            .frame(width: 52, height: 52)
                        Image(systemName: task.icon ?? "doc.text.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(task.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
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
                .padding(.bottom, 20)
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .onTapGesture { editingTask = task }
        }
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
