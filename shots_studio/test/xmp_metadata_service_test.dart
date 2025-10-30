import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shots_studio/models/screenshot_model.dart';
import 'package:shots_studio/services/xmp_metadata_service.dart';

import 'xmp_metadata_service_test.mocks.dart';

@GenerateMocks([SharedPreferences, PackageInfo])
void main() {
  late MockSharedPreferences mockPrefs;
  late MockPackageInfo mockPackageInfo;
  final tempDir = Directory.systemTemp.createTempSync('xmp_test');
  final tempFile = File('${tempDir.path}/test_image.png');

  // A minimal 1x1 pixel red PNG
  final sampleImageBytes = Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
    0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 12, 73, 68, 65, 84,
    24, 87, 99, 248, 207, 192, 0, 0, 5, 9, 2, 1, 163, 114, 21, 217, 0, 0, 0, 0,
    73, 69, 78, 68, 174, 66, 96, 130
  ]);

  setUpAll(() {
    // Create a dummy file for testing
    if (!tempFile.existsSync()) {
      tempFile.createSync(recursive: true);
    }
    tempFile.writeAsBytesSync(sampleImageBytes);
  });

  tearDownAll(() {
    // Clean up the dummy directory and file
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });


  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockPackageInfo = MockPackageInfo();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'shots_studio',
      packageName: 'com.example.shots_studio',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('XMPMetadataService', () {
    test('isXMPWritingEnabled returns true when enabled', () async {
      SharedPreferences.setMockInitialValues({'xmp_writing_enabled': true});
      expect(await XMPMetadataService.isXMPWritingEnabled(), isTrue);
    });

    test('isXMPWritingEnabled returns false when not enabled', () async {
      SharedPreferences.setMockInitialValues({'xmp_writing_enabled': false});
      expect(await XMPMetadataService.isXMPWritingEnabled(), isFalse);
    });

    test('writeXMPMetadata returns false if writing is disabled', () async {
      SharedPreferences.setMockInitialValues({'xmp_writing_enabled': false});
      final screenshot = Screenshot(id: '1', path: tempFile.path, addedOn: DateTime.now());
      final result = await XMPMetadataService.writeXMPMetadata(screenshot: screenshot);
      expect(result, isFalse);
    });

    test('writeXMPMetadata returns false for screenshot with no path', () async {
      SharedPreferences.setMockInitialValues({'xmp_writing_enabled': true});
      final screenshot = Screenshot(id: '1', path: null, addedOn: DateTime.now());
      final result = await XMPMetadataService.writeXMPMetadata(screenshot: screenshot);
      expect(result, isFalse);
    });

    test('writeXMPMetadata returns false for non-existent file', () async {
      SharedPreferences.setMockInitialValues({'xmp_writing_enabled': true});
      final screenshot = Screenshot(id: '1', path: '/non/existent/file.jpg', addedOn: DateTime.now());
      final result = await XMPMetadataService.writeXMPMetadata(screenshot: screenshot);
      expect(result, isFalse);
    });

    test('writeXMPMetadata successfully writes metadata', () async {
      SharedPreferences.setMockInitialValues({'xmp_writing_enabled': true});
      final screenshot = Screenshot(
        id: '1',
        path: tempFile.path,
        title: 'Test Title',
        description: 'Test Description',
        tags: ['tag1', 'tag2'],
        addedOn: DateTime.now(),
      );

      final result = await XMPMetadataService.writeXMPMetadata(screenshot: screenshot);
      expect(result, isTrue);

      // Verify backup is cleaned up
      final backupFile = File('${tempFile.path}.backup');
      expect(backupFile.existsSync(), isFalse);
    });

    test('escapeXML correctly escapes special characters', () {
      const input = '< > & " \'';
      const expected = '&lt; &gt; &amp; &quot; &apos;';
      expect(XMPMetadataService.escapeXML(input), expected);
    });

    test('createXMPData generates correct XML', () async {
      final screenshot = Screenshot(
        id: '1',
        path: tempFile.path,
        title: 'Test Title',
        description: 'Test Description',
        tags: ['tag1', 'tag2'],
        addedOn: DateTime.now(),
      );

      final xmpData = await XMPMetadataService.createXMPData(screenshot);

      expect(xmpData, contains('<dc:title>'));
      expect(xmpData, contains('<rdf:li xml:lang="x-default">Test Title</rdf:li>'));
      expect(xmpData, contains('<dc:description>'));
      expect(xmpData, contains('<rdf:li xml:lang="x-default">Test Description</rdf:li>'));
      expect(xmpData, contains('<dc:subject>'));
      expect(xmpData, contains('<rdf:li>tag1</rdf:li>'));
      expect(xmpData, contains('<rdf:li>tag2</rdf:li>'));
      expect(xmpData, contains('<xmp:CreatorTool>Shots Studio 1.0.0</xmp:CreatorTool>'));
    });
  });
}
