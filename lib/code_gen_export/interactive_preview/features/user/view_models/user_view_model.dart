import 'package:flutter/foundation.dart';

class UserViewModel extends ChangeNotifier {
  final bool _isLoading = false;
  bool get isLoading => _isLoading;

  void loadData() {
  }
}
