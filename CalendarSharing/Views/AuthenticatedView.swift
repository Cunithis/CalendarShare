//
//  AuthenticatedView.swift
//  CalendarSharing
//
//  Created by Domantas Jocas on 17/11/2025.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

extension AuthenticatedView where Unauthenticated == EmptyView {
  init(@ViewBuilder content: @escaping () -> Content) {
    self.init(unauthenticated: nil, content: content)
  }
}

struct AuthenticatedView<Content, Unauthenticated>: View where Content: View, Unauthenticated: View {
    @EnvironmentObject private var viewModel: AuthenticationViewModel
    @State private var presentingLoginScreen = false
    @State private var presentingProfileScreen = false
    
    var unauthenticated: Unauthenticated?
    @ViewBuilder var content: () -> Content
    
    public init(unauthenticated: Unauthenticated?, @ViewBuilder content: @escaping () -> Content) {
        self.unauthenticated = unauthenticated
        self.content = content
    }
    
    public init(@ViewBuilder unauthenticated: @escaping () -> Unauthenticated, @ViewBuilder content: @escaping () -> Content) {
        self.init(unauthenticated: unauthenticated(), content: content)
    }
    
    
    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            switch viewModel.authenticationState {
            case .unauthenticated, .authenticating:
                VStack {
                        Text("Calendar Share")
                            .font(.largeTitle)
                        Text("Stay coordinated, effortlessly")
                            .font(.body)
                            .foregroundStyle(Color(red: 0.773, green: 0.792, blue: 0.914))
                    VStack(spacing: 20) { // spacing between rows
                        
                        // Row 1
                        HStack(spacing: 15) {
                            Image("users")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.blue)
                            
                            VStack(alignment:.leading,spacing: 4) {
                                Text("Create Groups")
                                    .font(.headline)
                                
                                
                                Text("Share calendars with friends, family and colleagues")
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 0.773, green: 0.792, blue: 0.914))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Row 2
                        HStack(spacing: 15) {
                            Image("calendar")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Propose Meetings")
                                    .font(.headline)
                                
                                Text("Click any date to suggest meetings and get instant responses")
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 0.773, green: 0.792, blue: 0.914))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(nil)
                        }

                        HStack(spacing: 15) {
                            Image("sparkles")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.yellow)
                            
                            VStack(alignment: .leading,spacing: 4) {
                                Text("Smart Suggestions")
                                    .font(.headline)
                                
                                Text("AI-powered free date finder analyzes everyone's schedule")
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 0.773, green: 0.792, blue: 0.914))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(nil)
                        }

                        // Row 4
                        HStack(spacing: 15) {
                            Image("message-circle")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.green)
                            
                            VStack(alignment:.leading,spacing: 4) {
                                Text("Built-in Chat")
                                    .font(.headline)
                                
                                Text("Discuss meeting details right in the app")
                                    .font(.subheadline)
                                    .foregroundColor(Color(red: 0.773, green: 0.792, blue: 0.914))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(nil)
                            .lineLimit(nil)
                        }
                    }
                    .padding()

                    .overlay(RoundedRectangle(cornerRadius:15)
                        .stroke(Color.white,lineWidth:1))
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(15)
                    .frame(maxWidth: UIScreen.main.bounds.width*0.9)

                    Button(action:
                            {
                        viewModel.reset()
                        presentingLoginScreen.toggle()
                    }
                    ) {
                        Text("Click here to get started")
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .padding(.top,20)
                    }

                }
                .sheet(isPresented: $presentingLoginScreen) {
                    AuthenticationView()
                        .environmentObject(viewModel)
                }
            case .authenticated:
                VStack {
                    content()
                }
                .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { event in
                    viewModel.signOut()
                    if let userInfo = event.userInfo, let info = userInfo["info"] {
                        print(info)
                    }
                }
                .sheet(isPresented: $presentingLoginScreen) {
                    AuthenticationView()
                        .environmentObject(viewModel)
                }
            }
        }
    }
}

struct AuthenticatedView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticatedView {
            Text("You're signed in.")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(.yellow)
            Button(action: {
                do {
                    try Auth.auth().signOut()
                    print("Signed out successfully")
                } catch {
                    print("Failed to sign out: \(error)")
                }
            }) {
                Text("Sign out")
            }
        }
    }
}
