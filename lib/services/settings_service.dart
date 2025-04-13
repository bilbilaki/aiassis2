import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  static const String _webhookUrlKey = 'n8n_webhook_url';
  // Add a default URL for initial setup
  static const String _defaultWebhookUrl =
      'YOUR_N8N_WEBHOOK_URL_HERE'; // <<< IMPORTANT: Set your default URL

  // Model parameters
  static const String _systemMessageKey = 'system_message';
  static const String _userMessageKey = 'user_message';
  static const String _maxTokensKey = 'max_tokens';
  static const String _temperatureKey = 'temperature';
  static const String _topKKey = 'top_k';
  static const String _topPKey = 'top_p';
  static const String _customMemoryKey = 'custom_memory';

  // Default values
  static const String _defaultSystemMessage = 'You are a helpful AI assistant.';
  static const String _defaultUserMessage = 'You are a helpful AI assistant.';
  static const int _defaultMaxTokens = 2000;
  static const double _defaultTemperature = 0.7;
  static const int _defaultTopK = 40;
  static const double _defaultTopP = 0.9;
  static const String _defaultCustomMemory = '{}';

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  Future<String> getWebhookUrl() async {
    final prefs = await _getPrefs();
    return prefs.getString(_webhookUrlKey) ?? _defaultWebhookUrl;
  }

  Future<void> saveWebhookUrl(String url) async {
    final prefs = await _getPrefs();
    await prefs.setString(_webhookUrlKey, url);
  }

  // Model parameters getters and setters
  Future<String> getSystemMessage() async {
    final prefs = await _getPrefs();
    return prefs.getString(_systemMessageKey) ?? _defaultSystemMessage;
  }

  Future<void> saveSystemMessage(String message) async {
    final prefs = await _getPrefs();
    await prefs.setString(_systemMessageKey, message);
  }

  Future<String> getUserMessage() async {
    final prefs = await _getPrefs();
    return prefs.getString(_userMessageKey) ?? _defaultUserMessage;
  }

  Future<void> saveUserMessage(String message) async {
    final prefs = await _getPrefs();
    await prefs.setString(_userMessageKey, message);
  }

  Future<int> getMaxTokens() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_maxTokensKey) ?? _defaultMaxTokens;
  }

  Future<void> saveMaxTokens(int tokens) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_maxTokensKey, tokens);
  }

  Future<double> getTemperature() async {
    final prefs = await _getPrefs();
    return prefs.getDouble(_temperatureKey) ?? _defaultTemperature;
  }

  Future<void> saveTemperature(double temp) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_temperatureKey, temp);
  }

  Future<int> getTopK() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_topKKey) ?? _defaultTopK;
  }

  Future<void> saveTopK(int topK) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_topKKey, topK);
  }

  Future<double> getTopP() async {
    final prefs = await _getPrefs();
    return prefs.getDouble(_topPKey) ?? _defaultTopP;
  }

  Future<void> saveTopP(double topP) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_topPKey, topP);
  }

  Future<Map<String, String>> getCustomMemory() async {
    final prefs = await _getPrefs();
    final memoryJson =
        prefs.getString(_customMemoryKey) ?? _defaultCustomMemory;
    try {
      final Map<String, dynamic> decoded = json.decode(memoryJson);
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      return {};
    }
  }

  Future<void> saveCustomMemory(Map<String, String> memory) async {
    final prefs = await _getPrefs();
    await prefs.setString(_customMemoryKey, json.encode(memory));
  }
}
