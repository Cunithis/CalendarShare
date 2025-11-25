import SwiftUI
import FirebaseFirestore
import Combine

private final class _CalendarDataControllerHolder: ObservableObject {
    @Published var controller: CalendarDataController?
}

enum ActiveSheet: Identifiable {
    case createEvent
    case dayEvents(Date)
    case editEvent(Event)

    var id: String {
        switch self {
        case .createEvent:
            return "createEvent"
        case .dayEvents(let date):
            return "dayEvents_\(date.timeIntervalSince1970)"
        case .editEvent(let event):
            return "editEvent_\(event.id ?? UUID().uuidString)"
        }
    }
}

struct CalendarView: View {
    @State private var currentDate = Date()
    @EnvironmentObject private var currentUser: CurrentUser
    @State private var selectedDate: Date? = nil
    @State private var activeSheet: ActiveSheet?
    @Environment(\.dismiss) private var dismiss

    @StateObject private var dataControllerHolder = _CalendarDataControllerHolder()
    @State private var groupEvents: [Event] = []
    @State private var groupProposals: [GroupProposal] = []

    // NEW — loading indicator
    @State private var isLeaving = false

    var groupId: String? = nil
    var groupName: String? = nil

    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                calendarHeader
                dayOfWeekHeader
                monthGrid
                    .padding(.horizontal)

                Spacer(minLength: 12)

                Button(action: {
                    activeSheet = .createEvent
                }) {
                    Text("Create event")
                }
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .createEvent:
                        EventView(groupId: groupId)
                            .environmentObject(currentUser)
                    case .dayEvents(let date):
                        DayEventsSheet(
                            date: date,
                            eventsSource: (groupId != nil ? groupEvents : currentUser.events),
                            isGroupMode: groupId != nil,
                            groupId: groupId,
                            groupProposals: groupProposals
                        )
                        .environmentObject(currentUser)
                    case .editEvent(let event):
                        EventView(existingEvent: event)
                            .environmentObject(currentUser)
                    }
                }

                if let gid = groupId {
                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            UIPasteboard.general.string = gid
                        } label: {
                            Label("Copy group ID", systemImage: "doc.on.doc")
                                .padding(.horizontal, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .labelStyle(.titleAndIcon)

                        Button(role: .destructive) {
                            withAnimation { isLeaving = true }
                            Task {
                                await leaveGroupAndCleanupIfNeeded()
                                withAnimation { isLeaving = false }
                            }
                        } label: {
                            Label("Leave Group", systemImage: "person.fill.xmark")
                                .padding(.horizontal, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .labelStyle(.titleAndIcon)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding([.horizontal, .bottom])
                    .containerRelativeFrame(.horizontal)
                }
            }
            .padding()
            .onAppear {
                if let gid = groupId {
                    if dataControllerHolder.controller == nil {
                        // TODO: Consider using CalendarDataController registry to reuse listeners across views to reduce Firestore connections.
                        dataControllerHolder.controller = CalendarDataController(currentUser: currentUser, groupId: gid)
                        groupEvents = dataControllerHolder.controller?.groupEvents ?? []
                        groupProposals = dataControllerHolder.controller?.groupProposals ?? []
                        dataControllerHolder.controller?.startListenersIfNeeded()
                    }
                }
            }
            .onChange(of: dataControllerHolder.controller?.groupEvents ?? []) { _, newValue in
                groupEvents = newValue
            }
            .onChange(of: dataControllerHolder.controller?.groupProposals ?? []) { _, newValue in
                groupProposals = newValue
            }
            .onDisappear {
                dataControllerHolder.controller?.stopListeners()
            }
            .containerRelativeFrame(.horizontal)
        }
        .overlay {
            if isLeaving {
                loadingOverlay
            }
        }
        .containerRelativeFrame(.horizontal)
    }

    // MARK: - LOADING OVERLAY
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())

                Text("Leaving group…")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .animation(.easeInOut, value: isLeaving)
    }

    // MARK: - Delete Event
    private func deleteEvent(_ event: Event) {
        guard let uid = currentUser.user?.id,
              let eventId = event.id else { return }

        let db = Firestore.firestore()

        db.collection("users")
            .document(uid)
            .collection("calendar")
            .document(eventId)
            .delete { err in
                if let err = err {
                    print("Failed to delete: \(err)")
                } else {
                    currentUser.events.removeAll { $0.id == event.id }
                }
            }
    }

    private func eventDescription(_ event: Event) -> String {
        if event.occuringOnDays.allSatisfy({ (1...7).contains($0) }){
            return "Weekly"
        }
        return "Specific date"
    }

    // MARK: - CALENDAR UI
    private var calendarHeader: some View {
        HStack {
            if Date() <= currentDate {
                Button(action: { changeMonth(-1) }) {
                    Image(systemName: "chevron.left")
                }
            }

            Spacer()

            Text(monthYearString(currentDate))
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    private var dayOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(mondayFirstWeekdaySymbols(), id: \.self) { day in
                Text(day)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
        }
        .padding(.vertical, 4)
    }

    private func mondayFirstWeekdaySymbols() -> [String] {
        CalendarUIHelpers.mondayFirstWeekdaySymbols()
    }

    private var monthGrid: some View {
        let days = makeMonthDays(for: currentDate)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
            ForEach(days.indices, id: \.self) { idx in
                calendarCell(for: days[idx])
            }
        }
    }

    private func calendarCell(for date: Date?) -> some View {
        Group {
            if let date = date {
                let hasEvents = !eventsFor(date: date).isEmpty
                let hasProposals = (groupId != nil) ? !proposalsFor(date: date).isEmpty : false

                Button(action: {
                    selectedDate = date
                    DispatchQueue.main.async {
                        activeSheet = .dayEvents(date)
                    }
                }) {
                    VStack(spacing: 6) {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .padding(6)
                            .background(isToday(date) ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(Circle())

                        if hasEvents || hasProposals {
                            Circle()
                                .frame(width: 6, height: 6)
                                .foregroundColor(hasProposals ? .red : .accentColor)
                        } else {
                            Spacer().frame(height: 6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            } else {
                Text("").frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func proposalsFor(date: Date) -> [GroupProposal] {
        let eventsFromProposals = groupProposals.map { proposalToEvent($0) }
        let matchingEvents = Recurrence.events(on: date, from: eventsFromProposals)
        let titles = Set(matchingEvents.map { $0.title })
        return groupProposals.filter { titles.contains($0.title) }
    }

    private func matchingProposal(for event: Event, on date: Date) -> GroupProposal? {
        groupProposals.first { p in
            p.title == event.title &&
            p.timeStart == event.timeStart &&
            p.timeEnd == event.timeEnd &&
            !Recurrence.events(on: date, from: [proposalToEvent(p)]).isEmpty
        }
    }

    private func changeMonth(_ direction: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: direction, to: currentDate) {
            currentDate = newDate
        }
    }

    private func monthYearString(_ date: Date) -> String {
        CalendarUIHelpers.monthYearString(date)
    }

    private func isToday(_ date: Date) -> Bool {
        CalendarUIHelpers.isToday(date)
    }

    private func eventsFor(date: Date) -> [Event] {
        let source = (groupId != nil) ? groupEvents : currentUser.events
        return Recurrence.events(on: date, from: source)
    }

    private func makeMonthDays(for date: Date) -> [Date?] {
        CalendarUIHelpers.makeMonthDays(for: date)
    }

    private func timeRangeString(_ event: Event) -> String {
        let startHour = event.timeStart / 60
        let startMin  = event.timeStart % 60
        let endHour   = event.timeEnd / 60
        let endMin    = event.timeEnd % 60
        return String(format: "%02d:%02d — %02d:%02d", startHour, startMin, endHour, endMin)
    }

    private func proposalToEvent(_ proposal: GroupProposal) -> Event {
        Event(
            id: nil,
            title: proposal.title,
            occuringOnDays: proposal.occuringOnDays,
            timeStart: proposal.timeStart,
            timeEnd: proposal.timeEnd
        )
    }

    private func addProposalToMyCalendar(_ event: Event) async {
        guard let uid = currentUser.user?.id else { return }
        let db = Firestore.firestore()
        var toSave = event
        toSave.id = nil
        do {
            let ref = try db.collection("users").document(uid).collection("calendar").addDocument(from: toSave)
            var saved = event
            saved.id = ref.documentID
            DispatchQueue.main.async {
                currentUser.events.append(saved)
            }
        } catch {
            print("[CalendarView] Failed to add proposal to personal calendar: \(error)")
        }
    }

    // MARK: - LEAVE GROUP + CLEANUP
    private func leaveGroupAndCleanupIfNeeded() async {
        guard let gid = groupId, let uid = currentUser.user?.id else { return }
        let db = Firestore.firestore()
        let groupRef = db.collection("groups").document(gid)

        do {
            let snap = try await groupRef.getDocument()
            guard let data = snap.data(),
                  var members = data["members"] as? [String] else { return }

            if members.count == 1 {
                try await deleteAllDocs(in: groupRef.collection("calendar"))
                try await deleteAllDocs(in: groupRef.collection("proposals"))
                try await groupRef.delete()
                CurrentUser.shared.groups.removeAll(where:{$0.id == gid})
            } else {
                members.removeAll { $0 == uid }
                try await groupRef.updateData(["members": members])
                CurrentUser.shared.user?.groups.removeAll(where:{$0 == gid})
            }

            try await db.collection("users").document(uid)
                .updateData(["groups": FieldValue.arrayRemove([gid])])

            dismiss()

        } catch {
            print("[CalendarView] Failed to leave group or cleanup: \(error)")
        }
    }

    private func deleteAllDocs(in collectionRef: CollectionReference) async throws {
        let snapshot = try await collectionRef.getDocuments()
        for doc in snapshot.documents {
            try await collectionRef.document(doc.documentID).delete()
        }
    }
}

