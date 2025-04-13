import 'dart:convert';
import 'chat_message.dart';

class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime lastUpdatedAt;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.messages,
  });

  // Method to convert a Conversation instance to a JSON map list (for SharedPreferences)
  // Note: We store messages separately or embed them based on preference.
  // Here, we'll store a list of message IDs or the full messages. Storing full messages for simplicity here.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'messages': messages.map((msg) => msg.toJson()).toList(),
    };
  }

   // Factory constructor to create a Conversation instance from a JSON map
   factory Conversation.fromJson(Map<String, dynamic> json) {
     List<dynamic> messagesJson = json['messages'] ?? [];
     List<ChatMessage> messagesList = messagesJson
         .map((msgJson) => ChatMessage.fromJson(msgJson as Map<String, dynamic>))
         .toList();

     return Conversation(
       id: json['id'],
       title: json['title'],
       createdAt: DateTime.parse(json['createdAt']),
       lastUpdatedAt: DateTime.parse(json['lastUpdatedAt']),
       messages: messagesList,
     );
   }
}