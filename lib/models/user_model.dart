class UserModel {
  final String id;
  final String name;
  final int age;
  final String gender;
  final double latitude;
  final double longitude;
  final String location;
  final String? faceImagePath;
  final List<double>? faceVector;
  final String? preferredSports;
  final String? govtId;
  final DateTime registrationDate;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.latitude,
    required this.longitude,
    required this.location,
    this.faceImagePath,
    this.faceVector,
    this.preferredSports,
    this.govtId,
    required this.registrationDate,
    this.isVerified = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'faceImagePath': faceImagePath,
      'faceVector': faceVector,
      'preferredSports': preferredSports,
      'govtId': govtId,
      'registrationDate': registrationDate.toIso8601String(),
      'isVerified': isVerified,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      gender: json['gender'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      location: json['location'],
      faceImagePath: json['faceImagePath'],
      faceVector: (json['faceVector'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      preferredSports: json['preferredSports'],
      govtId: json['govtId'],
      registrationDate: DateTime.parse(json['registrationDate']),
      isVerified: json['isVerified'] ?? false,
    );
  }
}
