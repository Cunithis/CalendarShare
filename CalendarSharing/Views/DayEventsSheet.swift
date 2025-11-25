import SwiftUI
import FirebaseFirestore

struct DayEventsSheet: View {
    let date: Date
    let eventsSource: [Event]
    let isGroupMode: Bool
    let groupId: String?
    var groupProposals: [GroupProposal]

    @EnvironmentObject var currentUser: CurrentUser
    @Environment(\.dismiss) private var dismiss
    @State private var activeSheet: ActiveSheet?

    // MARK: - Convert proposal → Event for recurrence
    private func proposalToEvent(_ p: GroupProposal) -> Event {
        Event(
            id: nil,
            title: p.title,
            occuringOnDays: p.occuringOnDays,
            timeStart: p.timeStart,
            timeEnd: p.timeEnd,
            name: p.name
        )
    }

    // MARK: - Events for this date
    private var eventsForDate: [Event] {
        Recurrence.events(on: date, from: eventsSource)
    }

    // MARK: - Proposals for this date
    private var proposalsForDate: [GroupProposal] {
        // Convert proposals to Events, ask Recurrence which ones hit this date,
        // then match back to proposals by title + time window.
        let proposalEvents = groupProposals.map { proposalToEvent($0) }
        let matchingEvents = Recurrence.events(on: date, from: proposalEvents)

        return matchingEvents.compactMap { ev in
            groupProposals.first {
                $0.title == ev.title &&
                $0.timeStart == ev.timeStart &&
                $0.timeEnd == ev.timeEnd
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.bottom, 8)

                if eventsForDate.isEmpty && (!isGroupMode || proposalsForDate.isEmpty) {
                    Text("No events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    List {
                        // MARK: - Personal / Group Events
                        if !eventsForDate.isEmpty {
                            Section("Events") {
                                ForEach(eventsForDate) { event in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.title)
                                                .font(.headline)
                                            Text(timeRangeString(event))
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            if isGroupMode,
                                               let name = event.name,
                                               !name.isEmpty {
                                                Text("by \(name)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()

                                        // Only personal events can be edited here
                                        if !isGroupMode {
                                            Button {
                                                activeSheet = .editEvent(event)
                                            } label: {
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // MARK: - Group Proposals
                        if isGroupMode && !proposalsForDate.isEmpty {
                            Section("Proposed") {
                                ForEach(proposalsForDate) { p in
                                    let uid = currentUser.user?.id ?? ""

                                    HStack(alignment: .top) {
                                        // LEFT: info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(p.title)
                                                .font(.headline)

                                            Text(timeRangeString(proposalToEvent(p)))
                                                .font(.subheadline)
                                                .foregroundColor(.gray)

                                            if let name = p.name, !name.isEmpty {
                                                Text("by \(name)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            if !p.accepted.isEmpty {
                                                let acceptedNames = p.accepted.values.joined(separator: ", ")
                                                Text("Accepted by: \(acceptedNames)")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }

                                            if !p.declined.isEmpty {
                                                let declinedNames = p.declined.values.joined(separator: ", ")
                                                Text("Declined by: \(declinedNames)")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                        }

                                        Spacer()

                                        VStack(spacing: 8) {
                                            // USER HAS ACCEPTED
                                            if p.accepted[uid] != nil {
                                                Button {
                                                    Task { await acceptProposal(p) }   // stays accepted
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "checkmark.circle.fill")
                                                        Text("Accepted")
                                                    }
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.green)

                                                Button {
                                                    Task { await declineProposal(p) }  // switch to declined
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "xmark.circle")
                                                        Text("Decline")
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                                .tint(.red)
                                            }

                                            // USER HAS DECLINED
                                            else if p.declined[uid] != nil {
                                                Button {
                                                    Task { await acceptProposal(p) }  // switch to accepted
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "checkmark.circle")
                                                        Text("Accept")
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                                .tint(.green)

                                                Button {
                                                    Task { await declineProposal(p) }  // stays declined
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "xmark.circle.fill")
                                                        Text("Declined")
                                                    }
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.red)
                                            }

                                            // USER HAS NOT RESPONDED YET
                                            else {
                                                Button {
                                                    Task { await acceptProposal(p) }
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "checkmark.circle")
                                                        Text("Accept")
                                                    }
                                                }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.green)

                                                Button {
                                                    Task { await declineProposal(p) }
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "xmark.circle")
                                                        Text("Decline")
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                                .tint(.red)
                                            }
                                        }

                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Day Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .editEvent(let event):
                    EventView(existingEvent: event)
                        .environmentObject(currentUser)
                }
            }
        }
    }

    // MARK: - Helpers

    private func timeRangeString(_ event: Event) -> String {
        let h1 = event.timeStart / 60
        let m1 = event.timeStart % 60
        let h2 = event.timeEnd / 60
        let m2 = event.timeEnd % 60
        return String(format: "%02d:%02d — %02d:%02d", h1, m1, h2, m2)
    }

    private func acceptProposal(_ proposal: GroupProposal) async {
        guard let gid = groupId,
              let uid = currentUser.user?.id else { return }

        let db = Firestore.firestore()

        do {
            try await db.collection("groups").document(gid)
                .collection("proposals").document(proposal.id ?? "")
                .updateData([
                    "accepted.\(uid)": currentUser.user?.name ?? "",
                    "declined.\(uid)": FieldValue.delete()
                ])
        } catch {
            print("Failed to accept proposal: \(error)")
        }
    }

    private func declineProposal(_ proposal: GroupProposal) async {
        guard let gid = groupId,
              let uid = currentUser.user?.id else { return }

        let db = Firestore.firestore()

        do {
            try await db.collection("groups").document(gid)
                .collection("proposals").document(proposal.id ?? "")
                .updateData([
                    "declined.\(uid)": currentUser.user?.name ?? "",
                    "accepted.\(uid)": FieldValue.delete()
                ])
        } catch {
            print("Failed to decline proposal: \(error)")
        }
    }


    // MARK: - Local sheet enum (for editing events)

    private enum ActiveSheet: Identifiable {
        case editEvent(Event)

        var id: String {
            switch self {
            case .editEvent(let event):
                return event.id ?? UUID().uuidString
            }
        }
    }
}
