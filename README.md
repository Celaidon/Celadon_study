<div align="center">

<!-- PLACE YOUR BANNER IMAGE HERE (recommended: 1280x640px) -->
<!-- Example: ![Celadon Banner](images/banner.png) -->

<br/>

<img src="assets/main_screen.png" alt="Celadon" width="160"/>

<h1>C E L A D O N</h1>

<p><em>Your aesthetic study companion — plan smarter, study better.</em></p>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Live Demo](https://img.shields.io/badge/Live%20Demo-celadon--96aec.web.app-orange?style=for-the-badge&logo=google-chrome&logoColor=white)](https://celadon-96aec.web.app)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)](LICENSE)

<br/>

[**🌐 Live Demo**](https://celadon-96aec.web.app) &nbsp;·&nbsp; [🐛 Report Bug](../../issues) &nbsp;·&nbsp; [💡 Request Feature](../../issues)

<br/>

</div>

---

## 📸 Screenshots

> Add your screenshots inside an `images/` folder at the root of your repo and update the paths below.

<br/>

| Login Screen | Today's Tasks | Study Tracker |
|:---:|:---:|:---:|
| ![Login](images/screenshot_login.png) | ![Today](images/screenshot_today.png) | ![Study](images/screenshot_study.png) |

| Calendar | Full Calendar | Syllabus Roadmap |
|:---:|:---:|:---:|
| ![Calendar](images/screenshot_calendar_mini.png) | ![Full Calendar](images/screenshot_calendar_full.png) | ![Syllabus](images/screenshot_syllabus.png) |

> 📌 **Where to place images:** Create a folder `images/` in the project root, name your screenshots as shown above, and commit them.

---

## ✨ Features

### 🔐 Authentication
- Email & password **Sign Up** and **Sign In**
- **Persistent login sessions** — stay logged in after closing the browser
- **Forgot password** — reset via email link
- Reactive routing — the UI instantly switches between login/app on auth state change

### ✅ Today's Task Manager
- Add, complete, and delete **daily tasks**
- Completed tasks auto-clear after **24 hours**
- Smooth slide-in/out animations on add & delete
- Animated **bear mascot** with rotating motivational quotes

### 📅 Calendar
- **Mini calendar widget** embedded directly on the home screen
- Tap to open a full-screen **monthly calendar modal**
- Mark any date as **Holiday 🧡**, **Work Day 💚**, or a custom **Event 💜**
- Colour-coded dots and full month view
- Hover animations on every day cell (web & desktop)
- All markings **sync to the cloud** instantly

### 📚 Study Hours Tracker
- Track **actual vs. goal hours** per subject
- Beautiful **animated circular progress ring** for daily goal
- Motivational status messages based on study progress
- Add, edit, and delete subjects with **custom colours**
- Daily study goal is editable and **persisted per user**

### 🗺️ Syllabus Roadmap *(AI-powered)*
- **Upload a PDF syllabus** and Gemini AI parses it instantly
- Auto-generates a **chapter-by-chapter study roadmap**
- Mark individual chapters as complete
- Visual progress tracking across the full syllabus

### 🌙 Dark / Light Theme
- Toggle between dark and light mode from the **profile sheet**
- Theme preference **saved to the cloud** — consistent across devices and sessions

### ☁️ Cloud Data Sync
All user data is securely stored in **Firebase Firestore**, organised per user:

| Data | Persists |
|---|:---:|
| Tasks (add, complete, delete) | ✅ |
| Calendar day events (holiday, workday, event) | ✅ |
| Study subjects + goal & actual hours | ✅ |
| Daily study goal | ✅ |
| Dark / Light mode preference | ✅ |
| Login session | ✅ |

### 🎨 Design & UX Highlights
- Warm **earthy brown & sage green** aesthetic palette
- Custom illustrated login screen background
- Bear mascot with white-background cutout via `ColorFilter`
- Hover & press animations: **scale, lift, glow** effects throughout
- Smooth **page transitions** and micro-animations on all interactive elements
- Fully **responsive layout** — web, mobile, and desktop
- **PWA-ready** — can be installed as an app on Android, iOS, and desktop

---

## 🛠️ Tech Stack

| Category | Technology / Tool |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) 3.x (Web + Mobile + Desktop) |
| **Language** | [Dart](https://dart.dev) 3.x |
| **Authentication** | [Firebase Authentication](https://firebase.google.com/products/auth) |
| **Database** | [Cloud Firestore](https://firebase.google.com/products/firestore) |
| **Hosting** | [Firebase Hosting](https://firebase.google.com/products/hosting) |
| **AI / ML** | [Google Gemini API](https://aistudio.google.com) via [`google_generative_ai`](https://pub.dev/packages/google_generative_ai) |
| **File Handling** | [`file_picker`](https://pub.dev/packages/file_picker) |
| **State Management** | `ChangeNotifier` + `InheritedNotifier` (no external package) |
| **Animations** | `AnimationController`, `AnimatedBuilder`, `MouseRegion` |
| **Version Control** | [Git](https://git-scm.com) + [GitHub](https://github.com) |
| **Design / Assets** | [Canva](https://canva.com) (logo & splash illustration) |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.12.0`
- [Dart SDK](https://dart.dev/get-dart) `>=3.0.0`
- A [Firebase project](https://console.firebase.google.com) with **Authentication** and **Firestore** enabled
- A [Google Gemini API key](https://aistudio.google.com/app/apikey) *(for syllabus AI feature)*

---

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/celadon.git
cd celadon
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Generate your `firebase_options.dart` using the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will create `lib/firebase_options.dart` automatically.

> ⚠️ **Do not commit this file.** It is already listed in `.gitignore`.

### 4. Add your Gemini API Key

Create the file `lib/secrets.dart` (gitignored):

```dart
// lib/secrets.dart
const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

### 5. Run the app

```bash
# Web (Chrome)
flutter run -d chrome

# Android / iOS
flutter run

# Windows Desktop
flutter run -d windows
```

---

## 🔥 Firebase Configuration

### Firestore Security Rules

In your **Firebase Console → Firestore → Rules**, paste the following to ensure each user can only access their own data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own documents
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

  }
}
```

Click **Publish** to apply.

### Required Firebase Services

| Service | How to Enable |
|---|---|
| **Firebase Authentication** | Console → Authentication → Sign-in method → Email/Password → Enable |
| **Cloud Firestore** | Console → Firestore Database → Create database |
| **Firebase Hosting** | Console → Hosting → Get started |

---

## 📦 Deployment (Firebase Hosting)

### Build the web release

```bash
flutter build web --release
```

### Deploy to Firebase

```bash
firebase login
firebase init hosting
# ✔ Public directory: build/web
# ✔ Single-page app: Yes
# ✔ GitHub Actions auto-deploy: No

firebase deploy --only hosting
```

Your live app will be at:
```
https://YOUR-PROJECT-ID.web.app
```

---

## 📁 Project Structure

```
celadon/
│
├── lib/
│   ├── main.dart                 # Full application code
│   ├── firebase_options.dart     # Firebase config — GITIGNORED, generate locally
│   └── secrets.dart              # Gemini API key — GITIGNORED, create locally
│
├── assets/
│   ├── main_screen.png           # Login screen background illustration
│   └── bear.png                  # Bear mascot PNG
│
├── web/
│   ├── index.html                # Web entry point & meta tags
│   ├── manifest.json             # PWA manifest (name, colours, icons)
│   └── icons/                    # App icons (192px, 512px)
│
├── images/                       # README screenshots (add yours here)
│
├── android/                      # Android platform files
├── ios/                          # iOS platform files
├── windows/                      # Windows platform files
│
├── pubspec.yaml                  # Flutter dependencies
├── firebase.json                 # Firebase Hosting config
├── .firebaserc                   # Firebase project alias
├── .gitignore
└── README.md
```

---

## 📋 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^4.10.0
  firebase_auth: ^6.5.2
  cloud_firestore: ^6.5.0
  google_generative_ai: ^0.4.6
  file_picker: ^8.1.7
```

---

## 🙈 Security Notes

The following files are **gitignored** and must be created locally:

| File | Purpose |
|---|---|
| `lib/firebase_options.dart` | Firebase project credentials |
| `lib/secrets.dart` | Gemini API key |

**Never commit API keys or credentials to a public repository.**

---

## 🤝 Contributing

Contributions are welcome!

1. **Fork** the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m "feat: add your feature"`
4. Push: `git push origin feature/your-feature-name`
5. Open a **Pull Request**

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

---

<div align="center">

Made with 🐻 and ☕ &nbsp;|&nbsp; Built with [Flutter](https://flutter.dev) & [Firebase](https://firebase.google.com)

**⭐ Star this repo if you found it useful!**

*"Study smart, not hard."*

</div>
