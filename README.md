# **Calendar Sharing**

**Calendar Sharing** is a collaborative scheduling application that allows users to create personal events, join groups, view other members’ calendars, and propose shared events. It provides a structured and efficient way to coordinate availability within teams, families, and friend groups.

## **Features**

### **Personal Calendar**
- Create weekly recurring events  
- Create specific-date events  
- Events are stored under each user's Firestore document  
- Recurrence behavior is fully handled by a custom recurrence engine  

### **Group Calendars**
- Join or leave groups  
- See all group members' calendars combined  
- Personal events are automatically mirrored into all groups the user belongs to  
- Real-time Firestore listeners keep calendars synchronized  

### **Event Proposals**
- Propose events visible to all group members  
- Members can **accept** or **decline** with name-based tracking  
- Proposals remain visible after accepting or declining  
- Recurrence logic supports both weekly and one-time proposals  

### **Real-Time Sync and Caching**
- Firestore snapshot listeners synchronize event and group data  
- `CurrentUser` maintains local cached data  
- Reduces database reads by keeping as much state as possible in memory  

## **Screenshots**



<p float="left">
  <img src="CalendarSharing/docs/IMG_8278.PNG" width="250" />
  <img src="CalendarSharing/docs/IMG_8279.PNG" width="250" />
  <img src="CalendarSharing/docs/IMG_8272.PNG" width="250" />
  <img src="CalendarSharing/docs/IMG_8273.PNG" width="250" />
  <img src="CalendarSharing/docs/IMG_8275.PNG" width="250" />
  <img src="CalendarSharing/docs/IMG_8276.PNG" width="250" />
  <img src="CalendarSharing/docs/IMG_8277.PNG" width="250" />
  <img src="CalendarSharing/docs/IMG_8280.PNG" width="250" />


</p>



## **Architecture Overview**

### **MVVM and Service-Based Structure**
- Views contain only UI code  
- ViewModels contain business logic and state handling  
- Services manage Firestore, authentication, and recurrence logic  
- `CurrentUser` acts as a centralized state manager and cache  

## **Technology Stack**
- SwiftUI  
- Firebase Authentication  
- Firebase Firestore  
- Combine  
- Swift Concurrency (async/await)  
- Custom Recurrence Engine  

## **Firebase Setup**

### 1. Create Firebase Project
Create a Firebase project and add an iOS app with your bundle identifier.

### 2. Add GoogleService-Info.plist
Download the configuration file and place it at:


CalendarSharing/GoogleService-Info.plist


This file must be included in Xcode but should **not** be committed to GitHub.

### 3. Enable Services
Enable the following in Firebase Console:
- Authentication (Email/Password)  
- Firestore Database  

### 4. Install Firebase SDK
Use Swift Package Manager:


https://github.com/firebase/firebase-ios-sdk


Required modules:
- FirebaseAuth  
- FirebaseFirestore  

### 5. Firestore Data Model

## Firestore Data Model

```text
users/{uid}
    id: String
    email: String
    name: String
    profilePicture: String
    groups: [String]               // list of group IDs the user belongs to

    calendar/{eventId}
        id: String
        title: String
        occuringOnDays: [Int]
        timeStart: Int
        timeEnd: Int
        name: String (optional)
```

```text
groups/{groupId}
    id: String
    name: String
    members: [String]              // list of user IDs in the group

    calendar/{eventId}
        id: String
        title: String
        occuringOnDays: [Int]
        timeStart: Int
        timeEnd: Int
        name: String (optional)

    proposals/{proposalId}
        id: String
        title: String
        occuringOnDays: [Int]
        timeStart: Int
        timeEnd: Int
        accepted: { uid: name }    // dictionary of accepted users
        declined: { uid: name }    // dictionary of declined users
        name: String (optional)
```



## **Development Notes**

### **Event Mirroring**
When a user creates, updates, or deletes a personal event, these actions are mirrored to all groups the user belongs to.

### **Proposal Dictionaries**
Proposals store acceptance/decline responses as:


accepted: { uid: name }
declined: { uid: name }


### **Recurrence Engine**
Handles:
- Weekly recurring events  
- Specific date events  
- One-time proposals  

## **Running the App**
1. Clone the repository  
2. Open the project in Xcode  
3. Add the Firebase configuration file  
4. Build and run the app on an iOS device or simulator  

## **To Be Added**
- License  
- Contribution guidelines  
- Roadmap  
- Additional screenshots  
- Further caching optimizations
- User view
- More..
