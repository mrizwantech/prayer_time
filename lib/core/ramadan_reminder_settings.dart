import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RamadanReminderSettings extends ChangeNotifier {
  static const _suhoorEnabledKey = 'ramadanSuhoorEnabled';
  static const _suhoorIntervalKey = 'ramadanSuhoorIntervalMinutes';
  static const _suhoorStartKey = 'ramadanSuhoorStartMinutesBeforeFajr';
  static const _iftarEnabledKey = 'ramadanIftarEnabled';
  static const _iftarMinutesKey = 'ramadanIftarMinutesBeforeMaghrib';

  bool _suhoorEnabled = true;
  int _suhoorIntervalMinutes = 5; // 5/10/15 selectable
  int _suhoorStartMinutesBeforeFajr = 60; // start 1 hour before Fajr
  bool _iftarEnabled = true;
  int _iftarMinutesBeforeMaghrib = 10; // single alert 10 minutes before

  bool get suhoorEnabled => _suhoorEnabled;
  int get suhoorIntervalMinutes => _suhoorIntervalMinutes;
  int get suhoorStartMinutesBeforeFajr => _suhoorStartMinutesBeforeFajr;
  bool get iftarEnabled => _iftarEnabled;
  int get iftarMinutesBeforeMaghrib => _iftarMinutesBeforeMaghrib;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _suhoorEnabled = prefs.getBool(_suhoorEnabledKey) ?? _suhoorEnabled;
    _suhoorIntervalMinutes = prefs.getInt(_suhoorIntervalKey) ?? _suhoorIntervalMinutes;
    _suhoorStartMinutesBeforeFajr = prefs.getInt(_suhoorStartKey) ?? _suhoorStartMinutesBeforeFajr;
    _iftarEnabled = prefs.getBool(_iftarEnabledKey) ?? _iftarEnabled;
    _iftarMinutesBeforeMaghrib = prefs.getInt(_iftarMinutesKey) ?? _iftarMinutesBeforeMaghrib;
    notifyListeners();
  }

  Future<void> setSuhoorEnabled(bool value) async {
    _suhoorEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_suhoorEnabledKey, value);
    notifyListeners();
  }

  Future<void> setSuhoorIntervalMinutes(int value) async {
    _suhoorIntervalMinutes = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_suhoorIntervalKey, value);
    notifyListeners();
  }

  Future<void> setSuhoorStartMinutesBeforeFajr(int value) async {
    _suhoorStartMinutesBeforeFajr = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_suhoorStartKey, value);
    notifyListeners();
  }

  Future<void> setIftarEnabled(bool value) async {
    _iftarEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_iftarEnabledKey, value);
    notifyListeners();
  }

  Future<void> setIftarMinutesBeforeMaghrib(int value) async {
    _iftarMinutesBeforeMaghrib = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_iftarMinutesKey, value);
    notifyListeners();
  }
}
