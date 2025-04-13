import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // For Uint8List
import 'package:aiassis2/services/settings_service.dart';
import 'package:aiassis2/services/storage_service.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart'; // Adjust import path if necessary

class ApiService {
  final http.Client _httpClient;
  final SettingsService _settingsService; // Inject settings service
  final StorageService _storageService; // Inject storage service

  ApiService(this._httpClient, this._settingsService, this._storageService);

  Future<ChatMessage> sendMessage({
    required String message,
    required String sessionId,
    required String model,
    File? fileAttachment,
    File? audioAttachment,
    Map<String, String>? customHeaders,
    Map<String, dynamic>? customBodyFields,
  }) async {
    final String apiUrl = await _settingsService.getWebhookUrl();
    if (apiUrl == 'YOUR_N8N_WEBHOOK_URL_HERE' || apiUrl.isEmpty) {
      throw Exception("n8n Webhook URL is not configured in settings.");
    }

    // Get all model parameters
    final systemMessage = await _settingsService.getSystemMessage();
    final userMessage = await _settingsService.getUserMessage();
    final maxTokens = await _settingsService.getMaxTokens();
    final temperature = await _settingsService.getTemperature();
    final topK = await _settingsService.getTopK();
    final topP = await _settingsService.getTopP();
    final customMemory = await _settingsService.getCustomMemory();

    ChatMessage responseMessage;

    try {
      // Create a regular POST request instead of MultipartRequest
      var request = http.Request('POST', Uri.parse(apiUrl));

      // Set the content type header
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';

      // Add standard fields
      var bodyFields = {
        'message': message,
        'sessionId': sessionId,
        'model': model,
        'system_message': systemMessage,
        'user_message': userMessage,
        'max_tokens': maxTokens.toString(),
        'temperature': temperature.toString(),
        'top_k': topK.toString(),
        'top_p': topP.toString(),
        'custom_memory': json.encode(customMemory),
      };

      // Add custom body fields if provided
      customBodyFields?.forEach((key, value) {
        bodyFields[key] = value.toString();
      });

      // Add custom headers if provided
      customHeaders?.forEach((key, value) {
        request.headers[key] = value;
      });

      // Handle file attachment
      if (fileAttachment != null) {
        bodyFields['file'] = 'data'; // As per the working curl example

        // Get file extension and determine type
        final fileExtension = fileAttachment.path.split('.').last.toLowerCase();
        String fileType = 'txt'; // Default type

        // Map common file extensions to their types
        switch (fileExtension) {
          case 'jpg':
          case 'jpeg':
          case 'png':
          case 'gif':
          case 'bmp':
            fileType = 'image';
            break;
          case 'pdf':
            fileType = 'pdf';
            break;
          case 'doc':
          case 'docx':
            fileType = 'document';
            break;
          case 'txt':
            fileType = 'txt';
            break;
          case 'mp3':
          case 'wav':
          case 'm4a':
          case 'aac':
            fileType = 'audio';
            break;
          case 'mp4':
          case 'mov':
          case 'avi':
            fileType = 'video';
            break;
          default:
            fileType =
                fileExtension; // Use the extension as type if not in our mapping
        }

        bodyFields['file_type'] = fileType;
      }

      // Handle audio attachment
      if (audioAttachment != null) {
        bodyFields['audio'] = 'data';

        // Get audio file extension and determine type
        final audioExtension =
            audioAttachment.path.split('.').last.toLowerCase();
        String audioType = 'm4a'; // Default type

        // Map common audio extensions to their types
        switch (audioExtension) {
          case 'mp3':
            audioType = 'mp3';
            break;
          case 'wav':
            audioType = 'wav';
            break;
          case 'm4a':
            audioType = 'm4a';
            break;
          case 'aac':
            audioType = 'aac';
            break;
          default:
            audioType =
                audioExtension; // Use the extension as type if not in our mapping
        }

        bodyFields['audio_type'] = audioType;
      }

      // Convert body fields to URL encoded form data
      request.bodyFields = bodyFields;

      // Send the request
      final streamedResponse = await _httpClient.send(request);

      // Process the response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        String responseText = response.body;
        try {
          // Parse the JSON response
          final jsonResponse = json.decode(responseText);
          // Extract the 'output' field from the JSON
          final outputText = jsonResponse['output'] as String? ?? responseText;

          responseMessage = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: outputText.isEmpty ? "(Received empty response)" : outputText,
            timestamp: DateTime.now(),
            isUser: false,
            modelUsed: model,
            type: MessageType.text,
          );
        } catch (e) {
          // If JSON parsing fails, use the raw response
          responseMessage = ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text:
                responseText.isEmpty
                    ? "(Received empty response)"
                    : responseText,
            timestamp: DateTime.now(),
            isUser: false,
            modelUsed: model,
            type: MessageType.text,
          );
        }
      } else {
        throw Exception(
          'API request failed with status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("Error sending message via API: $e");
      responseMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Error: Failed to get response. ${e.toString()}",
        timestamp: DateTime.now(),
        isUser: false,
        modelUsed: model,
        type: MessageType.text,
      );
    }
    return responseMessage;
  }

  // Helper to extract filename from Content-Disposition header
  String? _extractFileName(String? header) {
    if (header == null || !header.contains('filename=')) {
      return null;
    }
    try {
      final match = RegExp('filename="?([^"]+)"?').firstMatch(header);
      return match?.group(1);
    } catch (e) {
      return null; // Error parsing
    }
  }
}
