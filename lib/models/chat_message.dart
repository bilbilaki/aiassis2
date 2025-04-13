import 'dart:io';

enum MessageType { text, image, audio, file }

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isUser;
  final String? modelUsed; // For AI messages
  final String? filePath; // Path to local file (sent or received)
  final String? fileName; // Original filename
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.text, // Can be caption for files/audio
    required this.timestamp,
    required this.isUser,
    this.modelUsed,
    this.filePath,
    this.fileName,
    required this.type,
  });

  // Method to convert a ChatMessage instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isUser': isUser,
      'modelUsed': modelUsed,
      'filePath': filePath,
      'fileName': fileName,
      'type': type.toString().split('.').last, // Store enum as string
    };
  }

  // Factory constructor to create a ChatMessage instance from a JSON map
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      isUser: json['isUser'],
      modelUsed: json['modelUsed'],
      filePath: json['filePath'],
      fileName: json['fileName'],
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text, // Default to text if parsing fails
      ),
    );
  }

  // Helper to determine if this message contains renderable media
  bool get hasMedia => filePath != null && (type == MessageType.image || type == MessageType.audio);
  bool get isMedia => type == MessageType.image || type == MessageType.audio || type == MessageType.file;
}