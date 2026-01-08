import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an adhan available for download
class AdhanInfo {
  final String id;
  final String displayName;
  final String firebasePath;
  final String? description;

  const AdhanInfo({
    required this.id,
    required this.displayName,
    required this.firebasePath,
    this.description,
  });
}

/// Download progress callback
typedef DownloadProgressCallback = void Function(double progress);

/// Service to manage adhan downloads from Firebase Storage
class AdhanDownloadService {
  static final AdhanDownloadService _instance = AdhanDownloadService._internal();
  factory AdhanDownloadService() => _instance;
  AdhanDownloadService._internal();

  // Firebase Storage reference
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // SharedPreferences keys
  static const String _downloadedAdhansKey = 'downloaded_adhans';

  /// Available adhans in Firebase Storage
  /// Add more adhans here as you upload them to Firebase
  static const List<AdhanInfo> availableAdhans = [
    AdhanInfo(
      id: 'fajr_adhan',
      displayName: 'Fajr Adhan',
      firebasePath: 'adhans/fajr_adhan.mp3',
      description: 'Soft, melodic adhan traditionally used for Fajr prayer',
    ),
    AdhanInfo(
      id: 'regular_adhan',
      displayName: 'Regular Adhan',
      firebasePath: 'adhans/regular_adhan.mp3',
      description: 'Standard adhan for Dhuhr, Asr, Maghrib, and Isha prayers',
    ),
    // Add more adhans here as you upload them to Firebase:
    // AdhanInfo(
    //   id: 'makkah_adhan',
    //   displayName: 'Makkah Adhan',
    //   firebasePath: 'adhans/makkah_adhan.mp3',
    //   description: 'Beautiful adhan from Masjid al-Haram',
    // ),
  ];

  /// Get the local directory for storing downloaded adhans
  Future<Directory> get localAdhanDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final adhanDir = Directory('${appDir.path}/adhans');
    if (!await adhanDir.exists()) {
      await adhanDir.create(recursive: true);
    }
    return adhanDir;
  }

  /// Get local file path for an adhan
  Future<String> getLocalFilePath(String adhanId) async {
    final dir = await localAdhanDirectory;
    return '${dir.path}/$adhanId.mp3';
  }

  /// Check if an adhan is downloaded
  Future<bool> isAdhanDownloaded(String adhanId) async {
    final filePath = await getLocalFilePath(adhanId);
    return File(filePath).exists();
  }

  /// Get list of downloaded adhan IDs
  Future<List<String>> getDownloadedAdhans() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_downloadedAdhansKey) ?? [];
  }

  /// Save downloaded adhan to list
  Future<void> _saveDownloadedAdhan(String adhanId) async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = await getDownloadedAdhans();
    if (!downloaded.contains(adhanId)) {
      downloaded.add(adhanId);
      await prefs.setStringList(_downloadedAdhansKey, downloaded);
    }
  }

  /// Download an adhan from Firebase Storage
  /// Returns the local file path on success, null on failure
  Future<String?> downloadAdhan(
    String adhanId, {
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // Find adhan info
      final adhanInfo = availableAdhans.firstWhere(
        (a) => a.id == adhanId,
        orElse: () => throw Exception('Adhan not found: $adhanId'),
      );

      final localPath = await getLocalFilePath(adhanId);
      final localFile = File(localPath);

      // Get download URL from Firebase
      final ref = _storage.ref(adhanInfo.firebasePath);
      
      debugPrint('📥 Starting download: ${adhanInfo.displayName}');
      debugPrint('   Firebase path: ${adhanInfo.firebasePath}');
      debugPrint('   Local path: $localPath');

      // Create download task
      final downloadTask = ref.writeToFile(localFile);

      // Listen to progress
      downloadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('   Progress: ${(progress * 100).toStringAsFixed(1)}%');
        onProgress?.call(progress);
      });

      // Wait for download to complete
      await downloadTask;

      // Verify file exists
      if (await localFile.exists()) {
        await _saveDownloadedAdhan(adhanId);
        debugPrint('✅ Download complete: ${adhanInfo.displayName}');
        return localPath;
      } else {
        debugPrint('❌ Download failed: File not created');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return null;
    }
  }

  /// Delete a downloaded adhan
  Future<bool> deleteAdhan(String adhanId) async {
    try {
      final localPath = await getLocalFilePath(adhanId);
      final file = File(localPath);
      
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from downloaded list
      final prefs = await SharedPreferences.getInstance();
      final downloaded = await getDownloadedAdhans();
      downloaded.remove(adhanId);
      await prefs.setStringList(_downloadedAdhansKey, downloaded);
      
      debugPrint('🗑️ Deleted adhan: $adhanId');
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  /// Get file size of a downloaded adhan (for display)
  Future<String> getFileSize(String adhanId) async {
    try {
      final path = await getLocalFilePath(adhanId);
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (e) {
      debugPrint('Error getting file size: $e');
    }
    return 'Unknown';
  }

  /// Get remote file size from Firebase (before download)
  Future<String> getRemoteFileSize(String adhanId) async {
    try {
      final adhanInfo = availableAdhans.firstWhere((a) => a.id == adhanId);
      final ref = _storage.ref(adhanInfo.firebasePath);
      final metadata = await ref.getMetadata();
      final bytes = metadata.size ?? 0;
      
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      debugPrint('Error getting remote file size: $e');
      return 'Unknown';
    }
  }
}
