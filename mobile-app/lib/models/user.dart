class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'farmer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
    };
  }
}

class Farm {
  final String id;
  final String name;
  final String location;
  final double landSize;
  final String soilType;
  final bool irrigationAvailable;

  Farm({
    required this.id,
    required this.name,
    required this.location,
    required this.landSize,
    required this.soilType,
    required this.irrigationAvailable,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      landSize: (json['land_size'] as num?)?.toDouble() ?? 0.0,
      soilType: json['soil_type'] as String? ?? '',
      irrigationAvailable: json['irrigation_available'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'land_size': landSize,
      'soil_type': soilType,
      'irrigation_available': irrigationAvailable,
    };
  }
}

class Crop {
  final String id;
  final String farmId;
  final String cropType;
  final String currentStage;
  final String status;
  final String planningDate;
  final String expectedHarvestDate;

  Crop({
    required this.id,
    required this.farmId,
    required this.cropType,
    required this.currentStage,
    required this.status,
    required this.planningDate,
    required this.expectedHarvestDate,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'] as String? ?? '',
      farmId: json['farm_id'] as String? ?? '',
      cropType: json['crop_type'] as String? ?? '',
      currentStage: json['current_stage'] as String? ?? 'Germination',
      status: json['status'] as String? ?? 'Planning',
      planningDate: json['planning_date'] as String? ?? '',
      expectedHarvestDate: json['expected_harvest_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farm_id': farmId,
      'crop_type': cropType,
      'current_stage': currentStage,
      'status': status,
      'planning_date': planningDate,
      'expected_harvest_date': expectedHarvestDate,
    };
  }
}

class Activity {
  final String id;
  final String cropId;
  final String name;
  final String description;
  final String scheduledDate;
  final String status;

  Activity({
    required this.id,
    required this.cropId,
    required this.name,
    required this.description,
    required this.scheduledDate,
    required this.status,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String? ?? '',
      cropId: json['crop_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      scheduledDate: json['scheduled_date'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'crop_id': cropId,
      'name': name,
      'description': description,
      'scheduled_date': scheduledDate,
      'status': status,
    };
  }
}
