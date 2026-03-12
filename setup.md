# Setup Instructions for Sports Talent Assessment Flutter App

## Prerequisites

1. **Install Flutter SDK**
   - Download Flutter from: https://flutter.dev/docs/get-started/install
   - Make sure Flutter is added to your PATH
   - Verify installation: `flutter doctor`

2. **Install Android Studio or VS Code**
   - Android Studio: https://developer.android.com/studio
   - VS Code with Flutter extension: https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter

3. **Set up Android Device/Emulator**
   - Enable Developer Options on your Android device
   - Enable USB Debugging
   - Or create an Android Virtual Device (AVD) in Android Studio

## Installation Steps

1. **Navigate to project directory**
   ```bash
   cd sports_talent_assessment
   ```

2. **Get Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Check for any issues**
   ```bash
   flutter doctor
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure Overview

```
lib/
├── main.dart                 # App entry point with routing
├── models/                   # Data models
│   ├── user_model.dart      # User profile data structure
│   └── assessment_model.dart # Assessment data structure
├── providers/                # State management (Provider pattern)
│   ├── auth_provider.dart   # User authentication & registration
│   ├── face_recognition_provider.dart # Face detection & scanning
│   └── location_provider.dart # GPS location services
├── screens/                  # UI screens
│   ├── splash_screen.dart   # App loading screen
│   ├── registration_screen.dart # User registration form
│   ├── home_screen.dart     # Main dashboard
│   └── assessment_screen.dart # Assessment with face scanning
├── widgets/                  # Reusable UI components
│   └── face_capture_widget.dart # Face capture component
└── utils/                    # Utility functions
    ├── constants.dart       # App constants
    └── permissions.dart     # Permission handling
```

## Key Features Implemented

### ✅ Registration Flow
- Complete user profile creation
- GPS location fetching
- Face image capture
- Form validation

### ✅ Face Recognition
- Camera initialization
- Face detection simulation
- 5-second scanning countdown
- Verification status tracking

### ✅ Assessment Flow
- Test selection from home screen
- Face verification before test starts
- Person tracking indicators
- Status management

### ✅ Modern UI
- Material Design 3
- Responsive layout
- Card-based design
- Loading states and error handling

## Testing the App

1. **Registration Test**
   - Fill out the registration form
   - Allow location permissions
   - Capture face image
   - Complete registration

2. **Assessment Test**
   - Select a test from home screen
   - Wait for face scanning countdown
   - Verify face recognition
   - Complete assessment flow

## Troubleshooting

### Common Issues

1. **Camera not working**
   - Check device permissions
   - Ensure camera is not being used by another app
   - Test on physical device (emulator may have camera issues)

2. **Location not found**
   - Enable location services
   - Allow location permissions
   - Test outdoors for better GPS signal

3. **Dependencies not found**
   - Run `flutter clean`
   - Run `flutter pub get`
   - Restart your IDE

### Debug Commands

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Check for issues
flutter doctor -v

# Run in debug mode
flutter run --debug

# Run in release mode
flutter run --release
```

## Next Steps for Development

### Immediate Improvements
1. Replace camera preview placeholder with actual camera feed
2. Implement real face recognition using ML Kit
3. Add actual video recording for assessments
4. Implement real performance metrics calculation

### Advanced Features
1. Offline video analysis
2. Cheat detection algorithms
3. Performance benchmarking
4. Gamification (points, badges, leaderboards)
5. Backend integration for data sync

## Support

If you encounter any issues:
1. Check Flutter documentation: https://flutter.dev/docs
2. Review the README.md file
3. Check device permissions
4. Ensure all dependencies are properly installed
