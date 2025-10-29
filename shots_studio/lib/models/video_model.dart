import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

class Video {
  String id;
  String? path; // For mobile (file path)
  Uint8List? bytes; // For web (video bytes)
  String? title;
  String? description;
  List<String> tags;
  List<String> collectionIds;
  DateTime addedOn;
  int? fileSize;
  bool isDeleted;
  DateTime? reminderTime;
  String? reminderText;
  double? duration; // Video duration in seconds
  String? thumbnailPath; // Path to a thumbnail image

  Video({
    required this.id,
    this.path,
    this.bytes,
    this.title,
    this.description,
    required this.tags,
    List<String>? collectionIds,
    required this.addedOn,
    this.fileSize,
    this.isDeleted = false,
    this.reminderTime,
    this.reminderText,
    this.duration,
    this.thumbnailPath,
  }) : collectionIds = collectionIds ?? [];

  void addToCollections(List<String> collections) {
    collectionIds.addAll(
      collections.where((id) => !collectionIds.contains(id)),
    );
  }

  List<String> get uniqueCollectionIds {
    return collectionIds.toSet().toList();
  }

  void addToCollection(String collectionId) {
    if (!collectionIds.contains(collectionId)) {
      collectionIds.add(collectionId);
    }
  }

  void deduplicateCollections() {
    final uniqueIds = collectionIds.toSet().toList();
    collectionIds.clear();
    collectionIds.addAll(uniqueIds);
  }

  // Method to convert a Video instance to a Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'bytes': bytes != null ? base64Encode(bytes!) : null,
      'title': title,
      'description': description,
      'tags': tags,
      'collectionIds': collectionIds,
      'addedOn': addedOn.toIso8601String(),
      'fileSize': fileSize,
      'isDeleted': isDeleted,
      'reminderTime': reminderTime?.toIso8601String(),
      'reminderText': reminderText,
      'duration': duration,
      'thumbnailPath': thumbnailPath,
    };
  }

  // Factory constructor to create a Video instance from a Map (JSON)
  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String,
      path: json['path'] as String?,
      bytes:
          json['bytes'] != null ? base64Decode(json['bytes'] as String) : null,
      title: json['title'] as String?,
      description: json['description'] as String?,
      tags: List<String>.from(json['tags'] as List<dynamic>),
      collectionIds:
          List<String>.from(
            json['collectionIds'] as List<dynamic>,
          ).toSet().toList(), // Deduplicate on load
      addedOn: DateTime.parse(json['addedOn'] as String),
      fileSize: json['fileSize'] as int?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      reminderTime:
          json['reminderTime'] != null
              ? DateTime.parse(json['reminderTime'] as String)
              : null,
      reminderText: json['reminderText'] as String?,
      duration: json['duration'] as double?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  /// Factory method to create a Video from a file path
  static Future<Video> fromFilePath({
    required String id,
    required String filePath,
    String? customTitle,
    List<String>? initialTags,
    DateTime? customAddedOn,
    int? knownFileSize,
  }) async {
    final file = File(filePath);

    // Get file metadata
    final fileSize = knownFileSize ?? await file.length();
    final lastModified = customAddedOn ?? await file.lastModified();
    final fileName = filePath.split('/').last;

    return Video(
      id: id,
      path: filePath,
      title: customTitle ?? fileName,
      tags: initialTags ?? [],
      addedOn: lastModified,
      fileSize: fileSize,
    );
  }

  /// Factory method to create a Video from image bytes (for web or picked videos)
  static Video fromBytes({
    required String id,
    required Uint8List bytes,
    required String fileName,
    String? filePath,
    List<String>? initialTags,
    DateTime? customAddedOn,
  }) {
    return Video(
      id: id,
      path: filePath,
      bytes: bytes,
      title: fileName,
      tags: initialTags ?? [],
      addedOn: customAddedOn ?? DateTime.now(),
      fileSize: bytes.length,
    );
  }

  /// Factory method to create an updated copy of an existing video
  Video copyWith({
    String? title,
    String? description,
    List<String>? tags,
    List<String>? collectionIds,
    bool? isDeleted,
    DateTime? reminderTime,
    String? reminderText,
    double? duration,
    String? thumbnailPath,
  }) {
    return Video(
      id: id,
      path: path,
      bytes: bytes,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      collectionIds: collectionIds ?? this.collectionIds,
      addedOn: addedOn,
      fileSize: fileSize,
      isDeleted: isDeleted ?? this.isDeleted,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderText: reminderText ?? this.reminderText,
      duration: duration ?? this.duration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  void removeReminder() {
    reminderTime = null;
    reminderText = null;
  }

  void setReminder(DateTime time, {String? text}) {
    reminderTime = time;
    reminderText = text;
  }
}
