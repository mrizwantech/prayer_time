import 'package:flutter/foundation.dart';
import 'quran_api_client.dart';

class QuranProvider extends ChangeNotifier {
  final QuranApiClient _client = QuranApiClient();
  
  List<SurahSummary> _surahs = [];
  bool _isLoading = false;
  String? _error;

  List<SurahSummary> get surahs => _surahs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSurahs() async {
    if (_surahs.isNotEmpty) return; // Already loaded
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _surahs = await _client.fetchSurahs();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
