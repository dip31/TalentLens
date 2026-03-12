import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/face_recognition_provider.dart';
import '../models/user_model.dart';
import '../widgets/face_capture_widget.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _sportsController = TextEditingController();
  final _govtIdController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isCapturingFace = false;

  @override
  void initState() {
    super.initState();
    // Initialize camera for face capture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaceRecognitionProvider>().initializeCamera();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _sportsController.dispose();
    _govtIdController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    await context.read<LocationProvider>().getCurrentLocation();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    final locationProvider = context.read<LocationProvider>();
    if (locationProvider.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please get your location first')),
      );
      return;
    }

    if (!_isCapturingFace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture your face first')),
      );
      return;
    }

    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text),
      gender: _selectedGender,
      latitude: locationProvider.currentPosition!.latitude,
      longitude: locationProvider.currentPosition!.longitude,
      location: locationProvider.currentAddress ?? 'Unknown',
      faceImagePath: null,
      preferredSports: _sportsController.text.trim().isEmpty ? null : _sportsController.text.trim(),
      govtId: _govtIdController.text.trim().isEmpty ? null : _govtIdController.text.trim(),
      registrationDate: DateTime.now(),
    );

    // Try to read face vector from provider to persist
    final faceProvider = context.read<FaceRecognitionProvider>();
    await context.read<AuthProvider>().registerUser(
      user,
      faceVector: faceProvider.registeredFaceVector,
    );
    
    if (mounted && context.read<AuthProvider>().isAuthenticated) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add,
                        size: 48,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create Your Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Fill in your details to get started',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Personal Information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Age Field
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your age';
                          }
                          final age = int.tryParse(value);
                          if (age == null || age < 5 || age > 100) {
                            return 'Please enter a valid age (5-100)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Gender Selection
                      const Text('Gender'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Male'),
                              value: 'Male',
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Female'),
                              value: 'Female',
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sports and Govt ID
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Additional Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _sportsController,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Sports (e.g., Football, Athletics)',
                          prefixIcon: Icon(Icons.sports),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _govtIdController,
                        decoration: const InputDecoration(
                          labelText: 'Govt ID (Aadhaar / PAN)',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Location Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Consumer<LocationProvider>(
                        builder: (context, locationProvider, _) {
                          return Column(
                            children: [
                              if (locationProvider.isLoading)
                                const CircularProgressIndicator()
                              else if (locationProvider.currentAddress != null)
                                ListTile(
                                  leading: const Icon(Icons.location_on, color: Colors.green),
                                  title: const Text('Current Location'),
                                  subtitle: Text(locationProvider.currentAddress!),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: _getLocation,
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: _getLocation,
                                  icon: const Icon(Icons.location_on),
                                  label: const Text('Get Current Location'),
                                ),
                              
                              if (locationProvider.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    locationProvider.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Face Capture Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Face Recognition',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Capture your face for identity verification during assessments',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      
                      FaceCaptureWidget(
                        onFaceCaptured: () {
                          setState(() {
                            _isCapturingFace = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Register Button
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: authProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Complete Registration',
                            style: TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),
              
              if (context.read<AuthProvider>().error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    context.read<AuthProvider>().error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
