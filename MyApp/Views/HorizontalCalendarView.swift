import SwiftUI

struct HorizontalCalendarView: View {
    @Binding var selectedDate: Date
    @ObservedObject var vm: DayScheduleViewModel
    let calendar = Calendar.current
    
    let themePink = Color(red: 1.0, green: 0.54, blue: 0.54)
    let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.12)
    
    // Full scrollable range
    var dates: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (-14...14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    /// The 7 dates (Mon–Sun) of the week containing selectedDate.
    /// Exposed so other views can align columns with this strip.
    var visibleWeekDates: [Date] {
        let cal = calendar
        // Find the Monday of selectedDate's week (ISO: Monday = weekday 2)
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        comps.weekday = 2
        guard let monday = cal.date(from: comps) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(dates, id: \.self) { date in
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        
                        VStack(spacing: 8) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption2)
                                .foregroundColor(isSelected ? .white : .gray)
                            
                            Text(date.formatted(.dateTime.day()))
                                .font(.title3.weight(isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .primary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(isSelected ? themePink : Color.clear)
                                )
                            
                            let tasksForDay = vm.tasksFor(date: date)
                            if !tasksForDay.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(tasksForDay.prefix(2)) { task in
                                        Circle()
                                            .fill(task.color)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .frame(height: 10)
                            } else {
                                Spacer().frame(height: 10)
                            }
                        }
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedDate = date
                            }
                        }
                        .id(date)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(calendar.startOfDay(for: selectedDate), anchor: .center)
            }
        }
    }
}
