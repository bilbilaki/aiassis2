import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';
import '../services/input_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService;
  final InputService _inputService;
  final StorageService _storageService;
  final SettingsService _settingsService; // Added

  List<Conversation> _conversations = [];
  int _currentConversationIndex = -1; // -1 means no conversation selected/new
  String _sessionId = Uuid().v4(); // Generate session ID on provider creation
  String _selectedModel = "GPT-4"; // Default model
  bool _isLoading = false;
  bool _isRecording = false;
  File? _attachedFile; // Track the currently attached file

  ChatProvider(
    this._apiService,
    this._inputService,
    this._storageService,
    this._settingsService,
  ) {
    loadHistory();
    _inputService.isRecording(); // Initialize recorder early
  }

  // --- Getters ---
  List<Conversation> get conversations => _conversations;
  int get currentConversationIndex => _currentConversationIndex;
  Conversation? get currentConversation =>
      _currentConversationIndex >= 0 &&
              _currentConversationIndex < _conversations.length
          ? _conversations[_currentConversationIndex]
          : null;
  List<ChatMessage> get currentMessages => currentConversation?.messages ?? [];
  String get sessionId => _sessionId;
  String get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  bool get isRecording => _isRecording;
  File? get attachedFile => _attachedFile;

  // --- Actions ---

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();
    _conversations = await _storageService.loadConversations();
    if (_conversations.isNotEmpty) {
      _currentConversationIndex =
          0; // Select the latest conversation by default
    } else {
      _currentConversationIndex = -1;
      // Optional: Automatically create a "New Chat" if history is empty
      // createNewConversation(notify: false); // Avoid notifying if UI isn't ready
    }
    _isLoading = false;
    notifyListeners();
  }

  void createNewConversation({bool notify = true}) {
    final newConversationId = Uuid().v4();
    final newConversation = Conversation(
      id: newConversationId,
      title: "New Chat", // Generate a better default title later
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
      messages: [],
    );
    _conversations.insert(0, newConversation); // Add to the beginning
    _currentConversationIndex = 0; // Select the new one
    _sessionId = Uuid().v4(); // Start a new session for the new chat

    // No immediate save needed, will be saved when first message is sent
    if (notify) notifyListeners();
  }

  void selectConversation(int index) {
    if (index >= 0 && index < _conversations.length) {
      _currentConversationIndex = index;
      // Optionally regenerate session ID when switching, or maintain per conversation
      _sessionId = Uuid().v4(); // Let's regenerate for simplicity now
      notifyListeners();
    }
  }

  void setModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String text,
    File? fileAttachment,
    File? audioAttachment,
  }) async {
    // If we have an attached file but no fileAttachment parameter, use the attached file
    if (_attachedFile != null && fileAttachment == null) {
      fileAttachment = _attachedFile;
      _attachedFile = null; // Clear the attached file after using it
    }

    // Ensure a conversation exists
    if (currentConversation == null) {
      createNewConversation(notify: false); // Create one if none exists
      if (currentConversation == null) {
        // Still null after creation? Error.
        print(
          "Error: Could not create or find a conversation to send message.",
        );
        return;
      }
    }

    // 1. Create and add user message locally
    final userMessageId = Uuid().v4();
    MessageType userMessageType = MessageType.text;
    String? userFilePath = fileAttachment?.path ?? audioAttachment?.path;
    String? userFileName;

    if (fileAttachment != null) {
      userMessageType = MessageType.file; // Default to file
      // Basic image type detection based on extension
      if ([
        '.png',
        '.jpg',
        '.jpeg',
        '.gif',
        '.webp',
        '.bmp',
      ].any((ext) => fileAttachment!.path.toLowerCase().endsWith(ext))) {
        userMessageType = MessageType.image;
      }
      userFileName = fileAttachment.path.split(Platform.pathSeparator).last;
    } else if (audioAttachment != null) {
      userMessageType = MessageType.audio;
      userFileName = audioAttachment.path.split(Platform.pathSeparator).last;
    }

    final userMessage = ChatMessage(
      id: userMessageId,
      text: text, // User's text input always included
      timestamp: DateTime.now(),
      isUser: true,
      type: userMessageType,
      filePath: userFilePath,
      fileName: userFileName,
    );
    _addMessageToCurrentConversation(userMessage);
    saveCurrentConversation(); // Save after adding user message

    _isLoading = true;
    notifyListeners(); // Show user message and loading state immediately

    // 2. Send to API
    try {
      final aiResponse = await _apiService.sendMessage(
        message: text,
        sessionId: _sessionId,
        model: _selectedModel,
        fileAttachment: fileAttachment,
        audioAttachment: audioAttachment,
      );

      // 3. Add AI response locally
      _addMessageToCurrentConversation(aiResponse);
    } catch (e) {
      // Handle API error - Create an error message
      final errorMessage = ChatMessage(
        id: Uuid().v4(),
        text: "Error communicating with AI: ${e.toString()}",
        timestamp: DateTime.now(),
        isUser: false,
        type: MessageType.text,
        modelUsed: _selectedModel,
      );
      _addMessageToCurrentConversation(errorMessage);
    } finally {
      _isLoading = false;
      saveCurrentConversation(); // Save after receiving AI response or error
      notifyListeners();

      // Clean up temporary files if they were sent
      // Note: Do not delete files the user picked explicitly unless confirmed they are copies
      if (audioAttachment != null &&
          audioAttachment.path.contains('/recording_')) {
        // Delete temporary recordings
        await _storageService.deleteLocalFile(audioAttachment.path);
      }
      // Decide if fileAttachment should be deleted (e.g., if it was a temp copy)
    }
  }

  Future<void> pickAndSendFile({bool sendImmediately = false}) async {
    File? file = await _inputService.pickFile();
    if (file != null) {
      if (sendImmediately) {
        await sendMessage(text: "", fileAttachment: file);
      } else {
        _attachedFile = file;
        notifyListeners();
      }
    }
  }

  Future<void> startRecording() async {
    bool started = await _inputService.startRecording();
    if (started) {
      _isRecording = true;
      notifyListeners();
    } else {
      // Handle failure to start (e.g., permissions)
      print("Failed to start recording");
      // Optionally show error message to user
    }
  }

  Future<void> stopAndSendRecording() async {
    if (!_isRecording) return;

    _isRecording = false; // Update state immediately
    notifyListeners(); // Reflect UI change

    File? audioFile = await _inputService.stopRecording();
    if (audioFile != null) {
      // Send message with audio (text can be empty)
      await sendMessage(text: "", audioAttachment: audioFile);
      // Temporary audio file deletion is handled in sendMessage's finally block
    } else {
      print("Failed to get recording file after stopping.");
      // Optionally show error message
    }
  }

  void _addMessageToCurrentConversation(ChatMessage message) {
    if (currentConversation != null) {
      // Check if it's the first message to set the title
      if (currentConversation!.messages.isEmpty &&
          message.isUser &&
          message.text.isNotEmpty) {
        // Create a title from the first few words of the first user message
        currentConversation!.title =
            message.text.split(' ').take(5).join(' ') +
            (message.text.split(' ').length > 5 ? '...' : '');
      }

      currentConversation!.messages.add(message);
      currentConversation!.lastUpdatedAt = DateTime.now();
    } else {
      print("Error: Tried to add message but no conversation is selected.");
    }
  }

  Future<void> saveCurrentConversation() async {
    if (currentConversation != null) {
      await _storageService.saveSingleConversation(currentConversation!);
    }
  }

  Future<void> deleteCurrentConversation() async {
    if (currentConversation != null) {
      // Delete associated local files first
      for (var message in currentConversation!.messages) {
        await _storageService.deleteLocalFile(message.filePath);
      }
      // Delete conversation from storage
      await _storageService.deleteConversation(currentConversation!.id);
      _conversations.removeAt(_currentConversationIndex);
      // Select the next available conversation or reset
      _currentConversationIndex = _conversations.isNotEmpty ? 0 : -1;
      notifyListeners();
    }
  }

  // --- Settings Related ---
  Future<String> getWebhookUrl() async {
    return await _settingsService.getWebhookUrl();
  }

  Future<void> saveWebhookUrl(String url) async {
    await _settingsService.saveWebhookUrl(url);
  }

  Future<String> getSystemMessage() async {
    return await _settingsService.getSystemMessage();
  }

  Future<void> saveSystemMessage(String message) async {
    await _settingsService.saveSystemMessage(message);
  }

  Future<String> getUserMessage() async {
    return await _settingsService.getUserMessage();
  }

  Future<void> saveUserMessage(String message) async {
    await _settingsService.saveUserMessage(message);
  }

  Future<int> getMaxTokens() async {
    return await _settingsService.getMaxTokens();
  }

  Future<void> saveMaxTokens(int tokens) async {
    await _settingsService.saveMaxTokens(tokens);
  }

  Future<double> getTemperature() async {
    return await _settingsService.getTemperature();
  }

  Future<void> saveTemperature(double temp) async {
    await _settingsService.saveTemperature(temp);
  }

  Future<int> getTopK() async {
    return await _settingsService.getTopK();
  }

  Future<void> saveTopK(int topK) async {
    await _settingsService.saveTopK(topK);
  }

  Future<double> getTopP() async {
    return await _settingsService.getTopP();
  }

  Future<void> saveTopP(double topP) async {
    await _settingsService.saveTopP(topP);
  }

  Future<Map<String, String>> getCustomMemory() async {
    return await _settingsService.getCustomMemory();
  }

  Future<void> saveCustomMemory(Map<String, String> memory) async {
    await _settingsService.saveCustomMemory(memory);
  }

  void clearAttachedFile() {
    _attachedFile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _inputService.disposeRecorder(); // Clean up audio recorder
    super.dispose();
  }
}
