import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? village;
  final String? district;
  final String? role;
  final String? bio; 
  final String? profilePicture; 

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.village,
    this.district,
    this.role,
    this.bio,
    this.profilePicture,
  });
}

class AuthProvider with ChangeNotifier {
  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // 🚀 নতুন: ইউজারের সম্পূর্ণ প্রোফাইল ডেটা (ছবি ও বায়োসহ) ফেচ করার ফাংশন
  Future<void> fetchFullProfile() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (res.statusCode == 200) {
        final userData = jsonDecode(res.body);
        _currentUser = UserModel(
          id: userData['_id']?.toString() ?? '',
          name: userData['name']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          phone: userData['phone']?.toString(),
          village: userData['village']?.toString() ?? '',
          district: userData['district']?.toString() ?? 'Khulna',
          role: userData['role']?.toString() ?? 'farmer',
          bio: userData['bio']?.toString() ?? '',
          profilePicture: userData['profilePicture']?.toString() ?? '',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching full profile: $e');
    }
  }

  // Sign Up Method
  Future<bool> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String village,
    required String district,
  }) async {
    _isLoading = true;
    clearMessages();
    notifyListeners();

    try {
      await ApiService.signup(
        name: name, email: email, password: password, phone: phone, village: village, district: district, role: 'farmer',
      );
      _successMessage = 'Account created successfully! Please sign in.';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign In Method
  Future<bool> signin({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    clearMessages();
    notifyListeners();

    try {
      final res = await ApiService.signin(email: email, password: password);

      try { _token = (res as dynamic)['token'] ?? (res as dynamic).token; } catch (_) { _token = (res as dynamic).token; }

      dynamic userData;
      try { userData = (res as dynamic)['user'] ?? (res as dynamic).user ?? res; } catch (_) { userData = res; }

      // লগইনের সময় বেসিক ডেটা সেট করা
      _currentUser = UserModel(
        id: (userData is Map ? userData['_id'] ?? userData['id'] : '')?.toString() ?? '',
        name: (userData is Map ? userData['name'] : (userData as dynamic).name)?.toString() ?? '',
        email: (userData is Map ? userData['email'] : (userData as dynamic).email)?.toString() ?? '',
        phone: (userData is Map ? userData['phone'] : (userData as dynamic).phone)?.toString(),
      );

      // 🚀 লগইন হওয়ার সাথে সাথেই ইউজারের ছবি ও বায়ো আনতে ডাটাবেসে রিকোয়েস্ট পাঠানো হলো
      await fetchFullProfile();

      _successMessage = 'Signed in successfully!';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void signout() {
    _currentUser = null;
    _token = null;
    clearMessages();
    notifyListeners();
  }

  // Update Profile Method
  Future<bool> updateProfile({
    required String name,
    required String phone,
    required String village,
    required String district,
    required String bio,
    required String profilePicture,
  }) async {
    _isLoading = true;
    clearMessages();
    notifyListeners();

    try {
      final response = await http.put(
        Uri.parse('http://localhost:5000/api/auth/me'),
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer $_token' },
        body: jsonEncode({
          'name': name, 'phone': phone, 'village': village, 'district': district, 'bio': bio, 'profilePicture': profilePicture,
        }),
      );

      if (response.statusCode == 200) {
        _currentUser = UserModel(
          id: _currentUser!.id, email: _currentUser!.email, role: _currentUser!.role,
          name: name, phone: phone, village: village, district: district, bio: bio, profilePicture: profilePicture,
        );
        _successMessage = 'Profile updated successfully!';
        return true;
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      _errorMessage = 'Network error or server down.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/auth/me'),
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer $_token' },
      );

      if (response.statusCode == 200) {
        signout();
        return true;
      } else {
        throw Exception('Failed to delete account');
      }
    } catch (e) {
      _errorMessage = 'Network error or server down.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}