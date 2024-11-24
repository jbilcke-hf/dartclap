import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

// Import your CLAP implementation
import 'package:clap/clap.dart';

void main() {
  group('CLAP File Tests', () {
    late ClapMeta sampleMeta;
    late List<ClapSegment> sampleSegments;
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory for file operations
      tempDir = await Directory.systemTemp.createTemp('clap_tests_');

      // Create sample metadata
      sampleMeta = ClapMeta(
        title: 'Test Project',
        description: 'A test project for CLAP parser',
        synopsis: 'Testing various CLAP features',
        bpm: 128,
        frameRate: 30,
        tags: ['test', 'demo', 'example'],
        width: 1920,
        height: 1080,
        imageRatio: ClapImageRatio.landscape,
        isLoop: true,
        isInteractive: false,
      );

      // Create sample segments
      sampleSegments = [
        ClapSegment(
          track: 0,
          startTimeInMs: 0,
          endTimeInMs: 5000,
          category: ClapSegmentCategory.video,
          prompt: 'Opening scene',
          label: 'Scene 1',
          outputType: ClapOutputType.video,
        ),
        ClapSegment(
          track: 1,
          startTimeInMs: 1000,
          endTimeInMs: 4000,
          category: ClapSegmentCategory.music,
          prompt: 'Background music',
          label: 'Music Track',
          outputType: ClapOutputType.audio,
        ),
      ];
    });

    tearDown(() async {
      // Clean up temporary directory after tests
      await tempDir.delete(recursive: true);
    });

    test('Create and serialize CLAP file', () async {
      final clap = ClapFile.create(
        meta: sampleMeta,
        segments: sampleSegments,
      );

      expect(clap.meta.title, equals('Test Project'));
      expect(clap.segments.length, equals(2));
      
      final bytes = await clap.serialize();
      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('Parse CLAP from bytes', () async {
      // First create and serialize
      final originalClap = ClapFile.create(
        meta: sampleMeta,
        segments: sampleSegments,
      );
      final bytes = await originalClap.serialize();

      // Then parse back
      final parsedClap = await ClapFile.fromSource(bytes);

      // Verify metadata
      expect(parsedClap.meta.title, equals(originalClap.meta.title));
      expect(parsedClap.meta.description, equals(originalClap.meta.description));
      expect(parsedClap.meta.bpm, equals(originalClap.meta.bpm));
      expect(parsedClap.meta.frameRate, equals(originalClap.meta.frameRate));
      expect(parsedClap.meta.imageRatio, equals(originalClap.meta.imageRatio));

      // Verify segments
      expect(parsedClap.segments.length, equals(originalClap.segments.length));
      
      for (var i = 0; i < parsedClap.segments.length; i++) {
        expect(parsedClap.segments[i].track, equals(originalClap.segments[i].track));
        expect(parsedClap.segments[i].startTimeInMs, equals(originalClap.segments[i].startTimeInMs));
        expect(parsedClap.segments[i].endTimeInMs, equals(originalClap.segments[i].endTimeInMs));
        expect(parsedClap.segments[i].category, equals(originalClap.segments[i].category));
        expect(parsedClap.segments[i].outputType, equals(originalClap.segments[i].outputType));
      }
    });

    test('Save and load CLAP file', () async {
      final filePath = path.join(tempDir.path, 'test.clap');
      
      // Create and save
      final originalClap = ClapFile.create(
        meta: sampleMeta,
        segments: sampleSegments,
      );
      await originalClap.saveToFile(filePath);

      // Verify file exists
      expect(await File(filePath).exists(), isTrue);

      // Load and verify
      final loadedClap = await ClapFile.fromSource(await File(filePath).readAsBytes());
      expect(loadedClap.meta.title, equals(originalClap.meta.title));
      expect(loadedClap.segments.length, equals(originalClap.segments.length));
    });

    test('Convert CLAP to data URI and back', () async {
      // Create original CLAP
      final originalClap = ClapFile.create(
        meta: sampleMeta,
        segments: sampleSegments,
      );

      // Convert to data URI
      final dataUri = await originalClap.toDataUri();
      expect(dataUri, startsWith('data:application/x-gzip;base64,'));

      // Parse back from data URI
      final parsedClap = await ClapFile.fromSource(dataUri);
      expect(parsedClap.meta.title, equals(originalClap.meta.title));
      expect(parsedClap.segments.length, equals(originalClap.segments.length));
    });

    test('Handle invalid CLAP data', () async {
      // Test invalid bytes
      expect(
        () async => await ClapFile.fromSource(Uint8List(0)),
        throwsA(isA<Exception>()),
      );

      // Test invalid YAML
      expect(
        () async => await ClapFile.fromSource('invalid: yaml: : content'),
        throwsA(isA<Exception>()),
      );

      // Test missing header
      final invalidYaml = '''
        --- 
        title: Test
        description: Invalid CLAP file
        ''';
      expect(
        () async => await ClapFile.fromSource(invalidYaml),
        throwsA(isA<Exception>()),
      );
    });

    test('Segment filtering and validation', () async {
      final clap = ClapFile.create(
        meta: sampleMeta,
        segments: sampleSegments,
      );

      // Test filtering by category
      final videoSegments = clap.segments.where(
        (s) => s.category == ClapSegmentCategory.video
      ).toList();
      expect(videoSegments.length, equals(1));

      final musicSegments = clap.segments.where(
        (s) => s.category == ClapSegmentCategory.music
      ).toList();
      expect(musicSegments.length, equals(1));

      // Test time range validation
      for (final segment in clap.segments) {
        expect(segment.startTimeInMs, lessThan(segment.endTimeInMs));
        expect(segment.startTimeInMs, greaterThanOrEqualTo(0));
      }
    });

    test('CLAP format version compatibility', () async {
      final clap = ClapFile.create(
        meta: sampleMeta,
        segments: sampleSegments,
      );
      
      final bytes = await clap.serialize();
      final parsed = await ClapFile.fromSource(bytes);
      
      // The version should be maintained through serialization/parsing
      expect(parsed.format, equals(ClapFormat.clap0));
    });
  });
}