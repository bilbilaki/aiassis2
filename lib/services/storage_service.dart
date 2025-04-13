import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../models/chat_message.dart'; // Ensure correct import path

class StorageService {
  static const String _conversationListKey = 'conversation_list';

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // --- Conversation History ---

  Future<List<Conversation>> loadConversations() async {
    final prefs = await _getPrefs();
    final List<String> conversationJsonList =
        prefs.getStringList(_conversationListKey) ?? [];
    List<Conversation> conversations = [];

    for (String conversationJson in conversationJsonList) {
      try {
        conversations.add(Conversation.fromJson(jsonDecode(conversationJson)));
      } catch (e) {
        print("Error decoding conversation: $e");
        // Optionally remove the corrupted entry
      }
    }
    // Sort conversations by last updated time (newest first)
    conversations.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
    return conversations;
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final prefs = await _getPrefs();
    List<String> conversationJsonList =
        conversations.map((conv) => jsonEncode(conv.toJson())).toList();
    await prefs.setStringList(_conversationListKey, conversationJsonList);
  }

   Future<void> saveSingleConversation(Conversation conversation) async {
      final conversations = await loadConversations();
      final index = conversations.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
         conversations[index] = conversation; // Update existing
      } else {
         conversations.add(conversation); // Add new
      }
      await saveConversations(conversations);
   }


  Future<void> deleteConversation(String conversationId) async {
    final conversations = await loadConversations();
    conversations.removeWhere((conv) => conv.id == conversationId);
    await saveConversations(conversations);
  }

  // --- File Storage ---

  Future<String?> saveFileLocally(Uint8List fileData, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Consider creating a subdirectory for chat files
      final dirPath = '${directory.path}/chat_files';
      await Directory(dirPath).create(recursive: true);

      // Ensure unique filename to avoid overwrites if needed
      // final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final filePath = '$dirPath/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileData, flush: true);
      print('File saved to: $filePath');
      return filePath;
    } catch (e) {
      print("Error saving file locally: $e");
      return null;
    }
  }

   Future<void> deleteLocalFile(String? filePath) async {
      if (filePath == null) return;
      try {
         final file = File(filePath);
         if (await file.exists()) {
            await file.delete();
            print("Deleted local file: $filePath");
         }
      } catch (e) {
         print("Error deleting local file $filePath: $e");
      }
   }
}