//
//  LoginView.swift
//  CalendarSharing
//
//  Created by Domantas Jocas on 17/11/2025.
//
import SwiftUI
import Combine
import AuthenticationServices

private enum FocusableField: Hashable {
  case email
  case password
}

struct LoginView: View {
  @EnvironmentObject var viewModel: AuthenticationViewModel
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.dismiss) var dismiss

  @FocusState private var focus: FocusableField?

  private func signInWithEmailPassword() {
    Task {
      if await viewModel.signInWithEmailPassword() == true {
        dismiss()
      }
    }
  }

  var body: some View {
          VStack {
            Text("Login")
              .font(.largeTitle)
              .fontWeight(.bold)
              .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
              Image(systemName: "at")
                TextField("", text: $viewModel.email, prompt:Text("Email").foregroundStyle(Color(red: 0.773, green: 0.792, blue: 0.914)))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit {
                  self.focus = .password
                }
                .foregroundStyle(Color.white)
            }
            .padding(.vertical, 6)
            .background(Divider(), alignment: .bottom)
            .padding(.bottom, 4)

            HStack {
              Image(systemName: "lock")
              SecureField("", text: $viewModel.password,
                          prompt:Text("Password").foregroundStyle(Color(red: 0.773, green: 0.792, blue: 0.914)))
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                  signInWithEmailPassword()
                }
            }
            .padding(.vertical, 6)
            .background(Divider(), alignment: .bottom)
            .padding(.bottom, 8)

            if !viewModel.errorMessage.isEmpty {
              VStack {
                Text(viewModel.errorMessage)
                  .foregroundColor(Color(UIColor.systemRed))
              }
            }

            Button(action: signInWithEmailPassword) {
              if viewModel.authenticationState != .authenticating {
                Text("Login")
                  .padding(.vertical, 8)
                  .frame(maxWidth: .infinity)
              }
              else {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .padding(.vertical, 8)
                  .frame(maxWidth: .infinity)
              }
            }
            .disabled(!viewModel.isValid)
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)

            HStack {
              VStack { Divider() }
              Text("or")
              VStack { Divider() }
            }
            HStack {
              Text("Don't have an account yet?")
              Button(action: { viewModel.switchFlow() }) {
                Text("Sign up")
                  .fontWeight(.semibold)
                  .foregroundColor(.blue)
              }
            }
            .padding([.top, .bottom], 50)

          }
          .listStyle(.plain)
          .padding()
        }
      }

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      LoginView()
      LoginView()
        .preferredColorScheme(.dark)
    }
    .environmentObject(AuthenticationViewModel())
  }
}
