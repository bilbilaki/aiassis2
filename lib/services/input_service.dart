import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class InputService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecorderInitialized = false;
  String? _recordingPath; // Store path during recording

  // Ensure recorder is initialized (needed for some platforms)
  Future<void> _initRecorder() async {
    if (!_isRecorderInitialized) {
       // Check permission status if needed, though record package often handles it
       if (await _audioRecorder.hasPermission()) {
         _isRecorderInitialized = true;
       } else {
         print("Audio recording permission denied.");
         // Handle permission denial gracefully (e.g., show a message)
       }
    }
  }

  // --- File Picking ---
  Future<File?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (e) {
      print("Error picking file: $e");
      // Handle exceptions (e.g., permissions denied)
    }
    return null;
  }

  // --- Voice Recording ---
  Future<bool> startRecording() async {
    await _initRecorder();
    if (!_isRecorderInitialized) return false;

    try {
       // Define where to save the recording
      final directory = await getTemporaryDirectory(); // Use temp dir
      _recordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a'; // Use a common format like m4a

      await _audioRecorder.start(
         const RecordConfig(encoder: AudioEncoder.aacLc), // Good balance of quality/size
         path: _recordingPath!,
      );
      print("Recording started: $_recordingPath");
      return true; // Indicate recording started
    } catch (e) {
      print("Error starting recording: $e");
      _recordingPath = null; // Clear path on error
      return false;
    }
  }

  Future<File?> stopRecording() async {
    if (!await _audioRecorder.isRecording()) {
       _recordingPath = null; // Ensure path is clear if not recording
       return null; // Not recording
    }

    try {
      final path = await _audioRecorder.stop();
      print("Recording stopped. File at: $path");
      // The path returned by stop() might be the one we need, or use _recordingPath
      final finalPath = path ?? _recordingPath;
      if (finalPath != null) {
         File recordingFile = File(finalPath);
        if (await recordingFile.exists()) {
           _recordingPath = null; // Clear path after successful stop
           return recordingFile;
        } else {
           print("Recording file does not exist at path: $finalPath");
           _recordingPath = null;
           return null;
        }
      }
    } catch (e) {
      print("Error stopping recording: $e");
    }
     _recordingPath = null; // Clear path on error or if stop returns null path
    return null;
  }

  Future<bool> isRecording() async {
     return await _audioRecorder.isRecording();
  }

  // Dispose the recorder when done
  void disposeRecorder() {
    _audioRecorder.dispose();
  }
}