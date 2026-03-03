import SwiftUI

struct TimelineView: View {
    @StateObject private var vm = DayScheduleViewModel()

    @State private var showingAdd = false
    @State private var editingTask: TaskItem?
    
    // Theme colors matching inspiration
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    let darkerBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54) // Coral pink
    
    // The X center of the vertical timeline line
    private var lineX: CGFloat {
        vm.timeColumnWidth + 10 + 22 - 0.75
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Header & Calendar Scroller
                VStack(spacing: 16) {
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(vm.selectedDate.formatted(.dateTime.day().month(.wide)))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
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
                    
                    HorizontalCalendarView(selectedDate: $vm.selectedDate, vm: vm)
                }
                .padding(.bottom, 15)
                .background(darkerBackground)
                .zIndex(1)
                
                // 2. Timeline Canvas
                ZStack(alignment: .bottomTrailing) {
                    
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
                                
                                // A. Time Labels (Far left)
                                TimeColumnView(vm: vm)
                                
                                // B. Colored Vertical Timeline Line
                                // Base: gray dashed line for the full 24 hours
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 0, y: vm.timelineHeight()))
                                }
                                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .offset(x: lineX)
                                
                                // Colored segments: each task paints its color over the line
                                ForEach(vm.layoutAttributes, id: \.task.id) { layout in
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: layout.yPos))
                                        path.addLine(to: CGPoint(x: 0, y: layout.yPos + layout.height))
                                    }
                                    .stroke(layout.task.color, style: StrokeStyle(lineWidth: 2.5))
                                    .offset(x: lineX)
                                    .zIndex(-1) // Behind the pills
                                }
                                
                                // C. Floating Current Time Label
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
                                
                                // D. Render Task Layouts (Overlap Engine)
                                ForEach(vm.layoutAttributes, id: \.task.id) { layout in
                                    
                                    // Overlap Warning Label — styled like inspiration:
                                    // "Tasks are " in gray + "overlapping" in coral pink
                                    if layout.showOverlapWarning {
                                        HStack(spacing: 0) {
                                            Text("Tasks are ")
                                                .foregroundColor(.gray)
                                            Text("overlapping")
                                                .foregroundColor(themePink)
                                        }
                                        .font(.caption.weight(.medium))
                                        .padding(.leading, vm.timeColumnWidth + 10 + 48 + 16)
                                        .offset(y: layout.warningYPos)
                                        .zIndex(100)
                                    }
                                    
                                    // Task Pill
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
                        .background(darkBackground)
                        .onAppear { scrollToCurrentHour(using: scrollProxy) }
                        .onChange(of: vm.selectedDate) { scrollToCurrentHour(using: scrollProxy) }
                    }
                    
                    // Add Button
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
                }
            }
            .background(darkerBackground.ignoresSafeArea())
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingAdd) {
            AddEditTaskView(viewModel: vm)
        }
        .sheet(item: $editingTask) { task in
            AddEditTaskView(viewModel: vm, taskToEdit: task)
        }
    }
    
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
