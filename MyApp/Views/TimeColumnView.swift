import SwiftUI

struct TimeColumnView: View {
    @ObservedObject var vm: DayScheduleViewModel
    var adaptivePPM: CGFloat? = nil
    
    var body: some View {
        if let ppm = adaptivePPM, let range = vm.selectedDayHourRange {
            // Adaptive mode: only show hours in the task range
            VStack(spacing: 0) {
                ForEach(range.lowerBound...range.upperBound, id: \.self) { hour in
                    let displayHour = hour == 24 ? 0 : hour
                    Text(vm.hourLabel(for: displayHour))
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: hour < range.upperBound ? 60 * ppm : 0, alignment: .top)
                        .offset(y: -7)
                }
            }
            .frame(width: vm.timeColumnWidth)
        } else if adaptivePPM != nil {
            // Adaptive mode but no tasks — show nothing
            EmptyView()
        } else {
            // Legacy fixed 24h mode
            VStack(spacing: 0) {
                ForEach(0..<25, id: \.self) { hour in
                    Text(vm.hourLabel(for: hour == 24 ? 0 : hour))
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Color.gray.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: 60 * vm.pixelsPerMinute, alignment: .top)
                        .offset(y: -7)
                }
            }
            .frame(width: vm.timeColumnWidth)
        }
    }
}
