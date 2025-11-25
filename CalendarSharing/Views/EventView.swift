import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct EventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var currentUser: CurrentUser
    @EnvironmentObject var viewModel: AuthenticationViewModel

    // If editing:
    var existingEvent: Event? = nil
    var groupId: String? = nil

    // Form fields
    @State private var title = ""       // weekly/biweekly/once
    @State private var occuringOnDays: [Int] = [] // weekdays OR epoch dates
    @State private var specificDates: [Date] = []

    @State private var selectedTimeStart = Date()
    @State private var selectedTimeEnd = Date()

    @State private var useWeekdays = true
    @State private var message = ""

    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Section(header: Text(existingEvent == nil ? "Create Event" : "Edit Event")) {
                        TextField("Title", text: $title)

                        if groupId != nil {
                            // Group mode: force one-time proposal, single date only
                            // Ensure state reflects one-time
                            EmptyView()
                                .onAppear {
                                    useWeekdays = false
                                    if specificDates.isEmpty { specificDates = [Date()] }
                                }

                            DatePicker("Select Date",
                                       selection: Binding(
                                           get: { specificDates.first ?? Date() },
                                           set: { specificDates = [$0] }
                                       ),
                                       displayedComponents: .date)
                        } else {
                            Picker("Select Type", selection: $useWeekdays) {
                                Text("Weekly").tag(true)
                                Text("Specific Dates").tag(false)
                            }
                            .pickerStyle(.segmented)

                            if useWeekdays {
                                WeekdayPicker(selectedDays: $occuringOnDays)

                            } else {
                                ForEach(specificDates.indices, id: \.self) { idx in
                                    HStack {
                                        DatePicker(
                                            "Select Date",
                                            selection: Binding(
                                                get: { specificDates[idx] },
                                                set: { specificDates[idx] = $0 }
                                            ),
                                            displayedComponents: .date
                                        )
                                        Button {
                                            specificDates.remove(at: idx)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }

                                Button("Add date") {
                                    specificDates.append(Date())
                                }
                            }
                        }

                        DatePicker("Start Time", selection: $selectedTimeStart, displayedComponents: .hourAndMinute)
                        DatePicker("End Time", selection: $selectedTimeEnd, displayedComponents: .hourAndMinute)
                    }

                    if existingEvent == nil {
                        Button("Create Event") {
                            Task { await createEvent() }
                        }
                    } else {
                        Button("Save Changes") {
                            Task { await updateEvent() }
                        }

                        Button(role: .destructive) {
                            Task { await deleteEvent() }
                        } label: {
                            Text("Delete Event")
                        }
                    }

                    if !message.isEmpty {
                        Text(message).foregroundColor(.green)
                    }
                }
            }
            .navigationTitle(existingEvent == nil ? "New Event" : "Edit Event")
            .onAppear { loadExistingIfNeeded() }
        }
    }

    // MARK: - Load Existing Event
    private func loadExistingIfNeeded() {
        guard let event = existingEvent else { return }

        title = event.title

        // Determine if this is a weekly event (only weekday indexes 1...7)
        if event.occuringOnDays.allSatisfy({ (1...7).contains($0) }) {
            useWeekdays = true
            occuringOnDays = event.occuringOnDays.sorted()
            specificDates = []   // just to be safe / clean
        } else {
            // Specific-date event: occuringOnDays stores epoch start-of-day ints
            useWeekdays = false
            occuringOnDays = []
            specificDates = event.occuringOnDays.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            }
        }
        // Convert timeStart/timeEnd (minutes) back into Date()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = event.timeStart / 60
        comps.minute = event.timeStart % 60
        selectedTimeStart = Calendar.current.date(from: comps) ?? Date()

        comps.hour = event.timeEnd / 60
        comps.minute = event.timeEnd % 60
        selectedTimeEnd = Calendar.current.date(from: comps) ?? Date()
    }


    // MARK: - Create
    private func createEvent() async {
        guard let uid = currentUser.user?.id else { return }

        let db = Firestore.firestore()

        let cal = Calendar.current
        let start = cal.component(.hour, from: selectedTimeStart) * 60 + cal.component(.minute, from: selectedTimeStart)
        let end   = cal.component(.hour, from: selectedTimeEnd)   * 60 + cal.component(.minute, from: selectedTimeEnd)

        let storedDays: [Int]

        if let gid = groupId {
            storedDays = [Recurrence.startOfDayEpochInt(for: specificDates.first!)]
        } else if useWeekdays {
            storedDays = occuringOnDays.sorted()
        } else {
            storedDays = specificDates.map { Recurrence.startOfDayEpochInt(for: $0) }
        }

        let event = Event(
            id: nil,
            title: title,
            occuringOnDays: storedDays,
            timeStart: start,
            timeEnd: end,
            name: currentUser.user?.name
        )

        let proposal = GroupProposal(
            id: nil,
            title: title,
            occuringOnDays: storedDays,
            timeStart: start,
            timeEnd: end,
            accepted: [:],
            declined: [:],
            name: currentUser.user?.name
        )

        do {
            if let gid = groupId {
                _ = try db.collection("groups")
                    .document(gid)
                    .collection("proposals")
                    .addDocument(from: proposal)
            } else {
                let ref = try db.collection("users")
                    .document(uid)
                    .collection("calendar")
                    .addDocument(from: event)

                var saved = event
                saved.id = ref.documentID
                currentUser.events.append(saved)

                await mirrorEventToGroupsOnCreate(saved)
            }

            dismiss()

        } catch {
            message = "Error creating event: \(error.localizedDescription)"
        }
    }


    // MARK: - Update
    private func updateEvent() async {
        guard let uid = currentUser.user?.id,
              var event = existingEvent,
              let eventId = event.id else { return }

        let db = Firestore.firestore()

        let storedDays: [Int] =
            useWeekdays
            ? occuringOnDays.sorted()
            : specificDates.map { Recurrence.startOfDayEpochInt(for: $0) }

        let cal = Calendar.current
        let start = cal.component(.hour, from: selectedTimeStart) * 60 + cal.component(.minute, from: selectedTimeStart)
        let end   = cal.component(.hour, from: selectedTimeEnd)   * 60 + cal.component(.minute, from: selectedTimeEnd)

        event.title = title
        event.occuringOnDays = storedDays
        event.timeStart = start
        event.timeEnd = end

        do {
            if groupId == nil {
                // PERSONAL EVENT UPDATE
                try db.collection("users")
                    .document(uid)
                    .collection("calendar")
                    .document(eventId)
                    .setData(from: event)

                if let index = currentUser.events.firstIndex(where: { $0.id == eventId }) {
                    currentUser.events[index] = event
                }

                await mirrorEventToGroupsOnUpdate(event)
            } else {
                // GROUP EVENT UPDATE — update only that one group
                try db.collection("groups")
                    .document(groupId!)
                    .collection("calendar")
                    .document(eventId)
                    .setData(from: event)
            }

            dismiss()
        } catch {
            message = "Error saving changes: \(error.localizedDescription)"
        }
    }


    // MARK: - Delete
    private func deleteEvent() async {
        guard let uid = currentUser.user?.id,
              let eventId = existingEvent?.id else { return }

        let db = Firestore.firestore()

        do {
            if groupId == nil {
                // PERSONAL EVENT DELETE
                try await db.collection("users").document(uid)
                    .collection("calendar")
                    .document(eventId)
                    .delete()

                currentUser.events.removeAll { $0.id == eventId }

                await mirrorEventToGroupsOnDelete(eventId)
            } else {
                // GROUP EVENT DELETE — delete only in this group
                try await db.collection("groups").document(groupId!)
                    .collection("calendar")
                    .document(eventId)
                    .delete()
            }

            dismiss()
        } catch {
            message = "Error deleting event: \(error)"
        }
    }


    // MARK: - Group Calendar Mirroring
    // Mirrors create/update/delete into all groups the current user belongs to.
    private func mirrorEventToGroupsOnCreate(_ event: Event) async {
        let db = Firestore.firestore()
        // Expect currentUser.groups to be a list containing group ids at currentUser.groups.map { $0.id }.
        // If your Group type uses a different property, replace `.id` accordingly.
        let groupIds: [String] = currentUser.groups.map { $0.id! }
        for gid in groupIds {
            do {
                // Use the same event payload; create a new document in the group's calendar.
                // We keep the same event.id if available to help correlate, otherwise Firestore assigns a new id.
                if let eid = event.id {
                    try db.collection("groups").document(gid).collection("calendar").document(eid).setData(from: event)
                } else {
                    _ = try db.collection("groups").document(gid).collection("calendar").addDocument(from: event)
                }
                print("[EventView] Mirrored event to group \(gid)")
            } catch {
                print("[EventView] Failed to mirror event to group \(gid): \(error)")
            }
        }
    }

    private func mirrorEventToGroupsOnUpdate(_ event: Event) async {
        let db = Firestore.firestore()
        guard let eid = event.id else { return }

        for gid in currentUser.groups.map({ $0.id! }) {
            do {
                try db.collection("groups").document(gid)
                    .collection("calendar").document(eid)
                    .setData(from: event)
            } catch {
                print("Failed to update mirrored event in group \(gid): \(error)")
            }
        }
    }


    private func mirrorEventToGroupsOnDelete(_ eventId: String) async {
        let db = Firestore.firestore()

        for gid in currentUser.groups.map({ $0.id! }) {
            do {
                try await db.collection("groups").document(gid)
                    .collection("calendar").document(eventId)
                    .delete()
            } catch {
                print("Failed to delete mirrored event in group \(gid): \(error)")
            }
        }
    }

}
