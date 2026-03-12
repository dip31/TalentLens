# Sports Talent Assessment - Flutter Prototype

An AI-powered mobile platform for democratizing sports talent assessment, built with Flutter.

## Features Implemented (30% Prototype)

### ✅ Core Features
- **User Registration**: Complete profile creation with face capture
- **Face Detection & Recognition**: Camera-based face scanning and verification
- **GPS Location**: Automatic location fetching during registration
- **Assessment Flow**: 5-second face scanning before test starts
- **Person Tracking**: Basic frame detection to ensure user stays in camera view
- **Modern UI**: Material Design 3 with responsive layout

### 🏗️ Architecture
- **State Management**: Provider pattern for reactive UI
- **Navigation**: GoRouter for type-safe navigation
- **Camera Integration**: Camera package for video capture
- **Location Services**: Geolocator for GPS coordinates
- **Local Storage**: SharedPreferences for user data persistence

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Android Studio / VS Code
- Android device or emulator (camera required)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd sports_talent_assessment
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Required Permissions

The app requires the following permissions:
- **Camera**: For face capture and assessment recording
- **Location**: For GPS coordinates during registration
- **Storage**: For saving captured images and videos

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user_model.dart
│   └── assessment_model.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   ├── face_recognition_provider.dart
│   └── location_provider.dart
├── screens/                  # UI screens
│   ├── splash_screen.dart
│   ├── registration_screen.dart
│   ├── home_screen.dart
│   └── assessment_screen.dart
├── widgets/                  # Reusable widgets
│   └── face_capture_widget.dart
└── utils/                    # Utilities
    ├── constants.dart
    └── permissions.dart
```

## User Flow

### 1. Registration Process
1. **Splash Screen**: App initialization and user check
2. **Registration Form**: 
   - Enter name, age, gender
   - Get GPS location automatically
   - Capture face image for verification
3. **Profile Creation**: Save user data locally

### 2. Assessment Process
1. **Home Screen**: View available tests and progress
2. **Test Selection**: Choose from 4 assessment types
3. **Face Verification**: 5-second scanning to match registered face
4. **Test Execution**: Record performance (simulated)
5. **Results**: Display completion status

## Available Tests

1. **Vertical Jump Test**: Measure explosive power
2. **Sit-ups Test**: Test core strength
3. **Shuttle Run Test**: Measure agility and speed
4. **Endurance Run Test**: Test cardiovascular fitness

## Technical Implementation

### Face Recognition
- Uses `camera_vision` package for face detection
- Simulates face matching (80% success rate for demo)
- Real implementation would use ML Kit or TensorFlow Lite

### Camera Integration
- Real-time camera preview
- Face detection overlay
- Person tracking indicators

### Location Services
- Automatic GPS coordinate fetching
- Address resolution using geocoding
- Permission handling for location access

## Future Enhancements (Remaining 70%)

### AI/ML Features
- [ ] Real face recognition using ML Kit
- [ ] Pose estimation for movement analysis
- [ ] Cheat detection algorithms
- [ ] Performance metrics calculation

### Backend Integration
- [ ] Secure API endpoints
- [ ] Video upload and processing
- [ ] Cloud storage for assessments
- [ ] Real-time synchronization

### Advanced Features
- [ ] Offline video analysis
- [ ] Performance benchmarking
- [ ] Gamification (points, badges, leaderboards)
- [ ] Progress tracking and analytics

### Testing & Quality
- [ ] Unit tests for business logic
- [ ] Widget tests for UI components
- [ ] Integration tests for user flows
- [ ] Performance optimization

## Development Notes

### Current Limitations
- Face recognition is simulated (not real ML)
- Camera preview is placeholder (not actual camera feed)
- Assessment recording is simulated
- No real backend integration

### Demo Features
- Complete user registration flow
- Face scanning countdown and verification
- Modern, responsive UI design
- State management with Provider
- Navigation between screens

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is part of the Sports Authority of India (SAI) talent assessment initiative.

## Support

For questions or issues, please contact the development team or create an issue in the repository.
