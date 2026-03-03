import SwiftUI

/// Legacy TimeColumnView — kept for compilation compatibility.
/// The day timeline now renders time labels inline per-task.
struct TimeColumnView: View {
    @ObservedObject var vm: DayScheduleViewModel
    var adaptivePPM: CGFloat? = nil
    
    var body: some View {
        EmptyView()
    }
}
