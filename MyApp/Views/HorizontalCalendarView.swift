import SwiftUI

/// Fixed 7-day strip (Mon→Sun) for a single week.
/// NOT scrollable — each week has its own strip as part of a paged layout.
struct HorizontalCalendarView: View {
    @Binding var selectedDate: Date
    @ObservedObject var vm: DayScheduleViewModel
    /// The exact 7 dates to display (passed from parent)
    let weekDates: [Date]
    
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { _, date in
                let isSelected = vm.calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = vm.calendar.isDateInToday(date)
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = date
                    }
                } label: {
                    VStack(spacing: 6) {
                        // Day name
                        Text(shortDayName(date))
                            .font(.caption2.weight(.medium))
                            .foregroundColor(isSelected ? .white : .gray)
                        
                        // Day number
                        Text("\(vm.calendar.component(.day, from: date))")
                            .font(.title3.weight(isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : (isToday ? themePink : .primary))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(isSelected ? themePink : Color.clear)
                            )
                        
                        // Task dots
                        let dayTasks = vm.tasksFor(date: date)
                        if !dayTasks.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(dayTasks.prefix(3)) { task in
                                    Circle()
                                        .fill(task.color)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .frame(height: 8)
                        } else {
                            Spacer().frame(height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private func shortDayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}
