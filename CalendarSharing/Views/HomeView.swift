import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct GroupRoute: Hashable {
    let id: String
    let name: String
}

struct HomeView: View {
    @State private var path = NavigationPath()
    @EnvironmentObject var viewModel: AuthenticationViewModel
    @EnvironmentObject var currentUser: CurrentUser
    
    @State private var presentingJoinGroupView = false
    @State private var presentingCreateGroupView = false
    
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                
                Image("background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                Color.black.opacity(0.4) // dark overlay
                    .ignoresSafeArea()
                ScrollView {
                VStack
                {
                        // Top buttons
                        HStack(spacing: 12) {
                            Button("My Calendar") {
                                path.append("calendar")
                            }
                            .padding()
                            .foregroundColor(.black)
                            .background(Color.white)
                            .cornerRadius(12)
                            Button("Sign out") {
                                viewModel.signOut()
                            }
                            .padding()
                            .foregroundColor(.black)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding()
                    Spacer()
                        HStack {
                            Text("Your Groups")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            Spacer()
                            Button(action: {
                                presentingCreateGroupView.toggle()
                            }) {
                                Image(systemName: "plus.circle")
                                    .padding()
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .sheet(isPresented: $presentingCreateGroupView) {
                                GroupCreateView().environmentObject(viewModel)
                            }
                            Button(action: {
                                presentingJoinGroupView.toggle()
                            }) {
                                Image(systemName: "person.badge.plus")
                                    .padding()
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .sheet(isPresented: $presentingJoinGroupView) {
                                GroupJoinView()
                            }
                        }
                    
                    

                        VStack(spacing: 16) { // spacing between cards
                            ForEach(currentUser.groups) { group in
                                Button {
                                    path.append(GroupRoute(id: group.id!, name: group.name))
                                } label: {
                                    HStack {
                                        Image(systemName: "person.3.fill") // optional icon
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("\(group.members.count) member(s)")
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 4)
                            }
                        }
                        .padding()
                    }.containerRelativeFrame(.horizontal)
                }
                .containerRelativeFrame(.horizontal)
                
                .navigationDestination(for: String.self) { value in
                    switch value {
                    case "calendar": CalendarView().environmentObject(currentUser)
                    case "eventTest": EventView().environmentObject(viewModel)
                    default: EmptyView()
                    }
                }
                .navigationDestination(for: GroupRoute.self) { route in
                    CalendarView(groupId: route.id, groupName: route.name)
                        .environmentObject(currentUser)
                }
                .task {// Start listening for groups when the view appears
                    if let uid = viewModel.user?.uid {
                        await viewModel.startListeningGroups(for: uid)
                        print("Loaded homeView uid=",viewModel.user?.uid ?? "nil")
                    }
                }
                .onDisappear {
                    // Stop listening when leaving the view
                    viewModel.stopListeningGroups()
                }
            }
        }.containerRelativeFrame(.horizontal)
    }
}
    struct HomeViewPreview: PreviewProvider {
        static var previews: some View {
            HomeView()
                .environmentObject(AuthenticationViewModel())
                .environmentObject(CurrentUser.shared)
        }
    }
    
