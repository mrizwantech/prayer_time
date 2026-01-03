import 'package:flutter/material.dart';

class TimeFormatSettings extends ChangeNotifier {
  bool _is24Hour = true;
  bool get is24Hour => _is24Hour;

  void toggleFormat() {
    _is24Hour = !_is24Hour;
    notifyListeners();
  }

  void setFormat(bool is24) {
    _is24Hour = is24;
    notifyListeners();
  }
}
