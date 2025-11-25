import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedDays: [Int] // 1 = Monday, 7 = Sunday
    
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                Button(action: {
                    toggle(day: day)
                    print("tapped day \(day)")
                }) {
                    Text(weekdays[day - 1])
                        .foregroundColor(selectedDays.contains(day) ? .white : .gray)
                        .padding(8)
                        .background(selectedDays.contains(day) ? Color.gray : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func toggle(day: Int) {
        if selectedDays.contains(day) {
            selectedDays.removeAll { $0 == day }
        } else {
            selectedDays.append(day)
        }
    }
}
