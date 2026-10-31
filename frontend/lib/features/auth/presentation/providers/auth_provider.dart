import 'package:flutter/material.dart';
import '../../data/datasources/auth_remote_datasource.dart';

class AuthProvider extends ChangeNotifier {
  final _authDataSource = AuthRemoteDataSource();
  
  bool isLoading = false;
  String? errorMessage;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authDataSource.login(email, password);
      isLoading = false;
      notifyListeners();
      return true; 
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false; 
    }
  }

  Future<bool> register(String name, String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authDataSource.register(name, email, password);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}