import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:shots_studio/models/video_model.dart';
import 'package:shots_studio/services/analytics/analytics_service.dart';
import 'package:shots_studio/services/file_watcher_service.dart';

/// Result class for video loading operations
class VideoLoadResult {
  final List<Video> videos;
  final String? errorMessage;
  final bool success;

  const VideoLoadResult({
    required this.videos,
    this.errorMessage,
    required this.success,
  });

  factory VideoLoadResult.success(List<Video> videos) {
    return VideoLoadResult(videos: videos, success: true);
  }

  factory VideoLoadResult.error(String errorMessage) {
    return VideoLoadResult(
      videos: [],
      errorMessage: errorMessage,
      success: false,
    );
  }
}

/// Progress callback for loading operations
typedef LoadingProgressCallback = void Function(int current, int total);

/// Service class responsible for loading videos from various sources
class VideoLoaderService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Load videos from gallery using image picker
  Future<VideoLoadResult> loadFromVideoPicker({
    required ImageSource source,
    required List<Video> existingVideos,
  }) async {
    try {
      final startTime = DateTime.now();

      // Log feature usage
      String sourceStr = 'gallery';
      AnalyticsService().logFeatureUsed('video_picker_$sourceStr');

      final XFile? videoFile = await _picker.pickVideo(source: source);

      if (videoFile == null) {
        return VideoLoadResult.success([]);
      }

      List<Video> newVideos = [];

      final bytes = await videoFile.readAsBytes();
      final String videoId = _uuid.v4();
      final String videoName = videoFile.name;

      // Check if a video with the same path already exists
      bool exists = false;
      if (!kIsWeb && videoFile.path.isNotEmpty) {
        exists = existingVideos.any((s) => s.path == videoFile.path);
      }

      if (exists) {
        print(
          'Skipping already loaded video: ${videoFile.path.isNotEmpty ? videoFile.path : videoName}',
        );
        return VideoLoadResult.success([]);
      }

      // Create video using centralized factory method
      final video = Video.fromBytes(
        id: videoId,
        bytes: bytes,
        fileName: videoName,
        filePath:
            kIsWeb
                ? null
                : (File(videoFile.path).existsSync() ? videoFile.path : null),
      );

      // For non-web platforms, prefer file path over bytes if file exists
      if (!kIsWeb && videoFile.path.isNotEmpty && File(videoFile.path).existsSync()) {
        // Clear bytes to save memory since we have the file path
        video.bytes = null;
      }

      newVideos.add(video);

      // Log video loading analytics
      final loadTime = DateTime.now().difference(startTime).inMilliseconds;
      AnalyticsService().logImageLoadTime(loadTime, sourceStr);

      return VideoLoadResult.success(newVideos);
    } catch (e) {
      // Log error analytics
      AnalyticsService().logNetworkError(e.toString(), 'video_picker');
      print('Error picking videos: $e');
      return VideoLoadResult.error('Error picking videos: $e');
    }
  }

  /// Load videos from Android device directories
  Future<VideoLoadResult> loadAndroidVideos({
    required List<Video> existingVideos,
    required bool isLimitEnabled,
    required int videoLimit,
    LoadingProgressCallback? onProgress,
    List<String>? customPaths,
  }) async {
    if (kIsWeb) {
      return VideoLoadResult.success([]);
    }

    try {
      var status = await Permission.videos.request();

      if (!status.isGranted) {
        String errorMessage =
            'Videos permission denied. Cannot load videos.';
        return VideoLoadResult.error(errorMessage);
      }

      // Get common Android video directories
      List<String> possibleVideoPaths = await _getVideoPaths();

      // Add custom paths if provided
      if (customPaths != null && customPaths.isNotEmpty) {
        possibleVideoPaths.addAll(customPaths);
      }

      List<FileSystemEntity> allFiles = [];

      for (String dirPath in possibleVideoPaths) {
        final directory = Directory(dirPath);
        if (await directory.exists()) {
          allFiles.addAll(
            directory.listSync().whereType<File>().where(
              (file) =>
                  file.path.toLowerCase().endsWith('.mp4') ||
                  file.path.toLowerCase().endsWith('.mov') ||
                  file.path.toLowerCase().endsWith('.avi'),
            ),
          );
        }
      }

      // Sort by last modified date (newest first)
      allFiles.sort((a, b) {
        return File(
          b.path,
        ).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });

      // Apply limit if enabled
      final limitedFiles =
          isLimitEnabled
              ? allFiles.take(videoLimit).toList()
              : allFiles.toList();

      List<Video> loadedVideos = [];
      int progress = 0;

      // Process files in batches to avoid memory spikes
      const int batchSize = 10;
      for (int i = 0; i < limitedFiles.length; i += batchSize) {
        final batch = limitedFiles.skip(i).take(batchSize);

        for (var fileEntity in batch) {
          final file = File(fileEntity.path);

          // Skip if already exists by path
          if (existingVideos.any((s) => s.path == file.path)) {
            print('Skipping already loaded file via path check: ${file.path}');
            progress++;
            onProgress?.call(progress, limitedFiles.length);
            continue;
          }

          // Check if the file is in trash and skip if it is
          if (FileWatcherService.isFileInTrash(file.path)) {
            print('Skipping trashed file: ${file.path}');
            progress++;
            onProgress?.call(progress, limitedFiles.length);
            continue;
          }

          final fileSize = await file.length();

          // Skip very large files to prevent memory issues
          if (fileSize > 500 * 1024 * 1024) {
            // Skip files larger than 500MB
            print('Skipping large file: ${file.path} ($fileSize bytes)');
            progress++;
            onProgress?.call(progress, limitedFiles.length);
            continue;
          }

          final video = await Video.fromFilePath(
            id: _uuid.v4(),
            filePath: file.path,
            knownFileSize: fileSize,
          );

          loadedVideos.add(video);

          progress++;
          onProgress?.call(progress, limitedFiles.length);
        }

        // Small delay to prevent UI blocking
        if (i % batchSize == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      return VideoLoadResult.success(loadedVideos);
    } catch (e) {
      print('Error loading Android videos: $e');
      return VideoLoadResult.error('Error loading Android videos: $e');
    }
  }

  /// Get common Android video directory paths
  Future<List<String>> _getVideoPaths() async {
    List<String> paths = [];

    try {
      // Get external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        String baseDir = externalDir.path.split('/Android')[0];

        // Common video paths on different Android devices
        paths.addAll([
          '$baseDir/DCIM/Camera',
          '$baseDir/Movies',
          '$baseDir/Download',
        ]);
      }
    } catch (e) {
      print('Error getting video paths: $e');
    }

    return paths;
  }

  /// Create a Video object from image bytes (useful for web uploads)
  Video createVideoFromBytes({
    required Uint8List bytes,
    required String fileName,
    String? path,
  }) {
    return Video.fromBytes(
      id: _uuid.v4(),
      bytes: bytes,
      fileName: fileName,
      filePath: path,
    );
  }

  /// Validate if a file is a supported video format
  bool isValidVideoFile(String filePath) {
    final lowercasePath = filePath.toLowerCase();
    return lowercasePath.endsWith('.mp4') ||
        lowercasePath.endsWith('.mov') ||
        lowercasePath.endsWith('.avi');
  }

  /// Get file size in a human-readable format
  String getFileSizeString(int fileSizeBytes) {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
