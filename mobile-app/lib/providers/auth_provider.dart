import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? village;
  final String? district;
  final String? role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.village,
    this.district,
    this.role,
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

  // Sign Up Method (auth_screen.dart-এর জন্য প্রয়োজনীয় মেথড)
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
        name: name,
        email: email,
        password: password,
        phone: phone,
        village: village,
        district: district,
        role: 'farmer',
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

  // Sign In Method (টোকেন ক্যাপচারসহ)
  Future<bool> signin({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    clearMessages();
    notifyListeners();

    try {
      final res = await ApiService.signin(
        email: email,
        password: password,
      );

      // ব্যাকএন্ড রেসপন্স অবজেক্ট বা ম্যাপ থেকে টোকেন নেওয়া
      try {
        _token = (res as dynamic)['token'] ?? (res as dynamic).token;
      } catch (_) {
        _token = (res as dynamic).token;
      }

      dynamic userData;
      try {
        userData = (res as dynamic)['user'] ?? (res as dynamic).user ?? res;
      } catch (_) {
        userData = res;
      }

      _currentUser = UserModel(
        id: (userData is Map ? userData['_id'] ?? userData['id'] : '')?.toString() ?? '',
        name: (userData is Map ? userData['name'] : (userData as dynamic).name)?.toString() ?? '',
        email: (userData is Map ? userData['email'] : (userData as dynamic).email)?.toString() ?? '',
        phone: (userData is Map ? userData['phone'] : (userData as dynamic).phone)?.toString(),
        village: (userData is Map ? userData['village'] : (userData as dynamic).village)?.toString() ?? '',
        district: (userData is Map ? userData['district'] : (userData as dynamic).district)?.toString() ?? 'Khulna',
        role: (userData is Map ? userData['role'] : (userData as dynamic).role)?.toString() ?? 'farmer',
      );

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

  // Sign Out Method
  void signout() {
    _currentUser = null;
    _token = null;
    clearMessages();
    notifyListeners();
  }
}