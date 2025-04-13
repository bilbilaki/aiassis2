import 'dart:io'; // For Platform check if needed
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/chat_message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/sidebar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _textScrollController = ScrollController();
  late AnimationController _buttonAnimationController;
  late AnimationController _sidebarAnimationController;
  final FocusNode _textFocusNode = FocusNode();
  bool _isRecording = false;
  bool _hasText = false;
  bool _isSidebarOpen = true;

  @override
  void initState() {
    super.initState();
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _sidebarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // Start with sidebar open
    );

    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
        if (hasText) {
          _buttonAnimationController.forward();
        } else {
          _buttonAnimationController.reverse();
        }
      }
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.addListener(_scrollToBottomListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      FocusScope.of(context).requestFocus(_textFocusNode);
    });
  }

  // Separate listener function for scrolling
  void _scrollToBottomListener() {
    // Check if the widget is still mounted before accessing context or scrolling
    if (mounted) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _textScrollController.dispose();
    _buttonAnimationController.dispose();
    _sidebarAnimationController.dispose();
    _textFocusNode.dispose();
    // Remove listener when disposing
    Provider.of<ChatProvider>(
      context,
      listen: false,
    ).removeListener(_scrollToBottomListener);
    super.dispose();
  }

  void _scrollToBottom() {
    // Add a small delay to ensure the list view has updated its layout
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      Provider.of<ChatProvider>(context, listen: false).sendMessage(text: text);
      _messageController.clear();
      _scrollToBottom();
      _textFocusNode.requestFocus();
    }
  }

  void _handleRecordButtonPress() {
    if (_hasText) return; // Don't start recording if there's text
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (chatProvider.isRecording) return;

    setState(() {
      _isRecording = true;
    });
    chatProvider.startRecording();
  }

  void _handleRecordButtonRelease() {
    if (_hasText) return; // Don't stop recording if there's text
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (!chatProvider.isRecording) return;

    setState(() {
      _isRecording = false;
    });
    chatProvider.stopAndSendRecording();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _sidebarAnimationController.forward();
      } else {
        _sidebarAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar with animation
              AnimatedBuilder(
                animation: _sidebarAnimationController,
                builder: (context, child) {
                  return ClipRect(
                    child: SizeTransition(
                      sizeFactor: _sidebarAnimationController,
                      axis: Axis.horizontal,
                      child: SizedBox(width: 260, child: Sidebar(width: 260)),
                    ),
                  );
                },
              ),

              // Main Chat Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: theme.dividerColor, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header Bar with Toggle Button
                      _buildHeader(context, chatProvider, theme),
                      // Rest of the content...
                      Expanded(
                        child: Consumer<ChatProvider>(
                          builder: (context, provider, child) {
                            final messages = provider.currentMessages;
                            if (provider.isLoading && messages.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (messages.isEmpty &&
                                !provider.isLoading) {
                              return _buildEmptyState(context, provider, theme);
                            } else {
                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final previousMessage =
                                      index > 0 ? messages[index - 1] : null;
                                  return MessageBubble(
                                    key: ValueKey(message.id),
                                    message: message,
                                    previousMessage: previousMessage,
                                  );
                                },
                              );
                            }
                          },
                        ),
                      ),
                      _buildInputArea(context, chatProvider, theme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ChatProvider chatProvider,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_arrow,
              progress: _sidebarAnimationController,
            ),
            onPressed: _toggleSidebar,
            tooltip: _isSidebarOpen ? 'Close Sidebar' : 'Open Sidebar',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chatProvider.currentConversation?.title.isEmpty ?? true
                  ? "New Chat"
                  : chatProvider.currentConversation!.title,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Model Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  theme.inputDecorationTheme.fillColor ??
                  theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: chatProvider.selectedModel,
                isDense: true,
                items:
                    ["GPT-4", "GPT-3.5", "Claude", "Llama", "Gemini"].map((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    chatProvider.setModel(newValue);
                  }
                },
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: theme.iconTheme.color?.withOpacity(0.7),
                ),
                dropdownColor: theme.colorScheme.surface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Settings button
          IconButton(
            icon: Icon(
              Icons.tune,
              color: theme.iconTheme.color?.withOpacity(0.8),
            ),
            onPressed: () {},
            tooltip: "Customize parameters",
          ),
        ],
      ),
    );
  }

  // --- Empty State / Suggestions Widget ---
  Widget _buildEmptyState(
    BuildContext context,
    ChatProvider chatProvider,
    ThemeData theme,
  ) {
    final isFantasy =
        Provider.of<ThemeProvider>(context, listen: false).isFantasyMode;

    return Center(
      child: SingleChildScrollView(
        // Allow scrolling if suggestions overflow
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFantasy
                  ? Icons.star_border_purple500_outlined
                  : Icons.chat_bubble_outline,
              size: 64,
              color:
                  isFantasy
                      ? theme.colorScheme.secondary
                      : theme.iconTheme.color?.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Start a new conversation",
              style:
                  isFantasy
                      ? theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      )
                      : theme.textTheme.titleLarge?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                      ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ask anything or select a suggestion",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip("Create a travel itinerary", chatProvider),
                _buildSuggestionChip("Help me debug this code", chatProvider),
                _buildSuggestionChip(
                  "Write a fantasy story intro",
                  chatProvider,
                ),
                _buildSuggestionChip(
                  "Explain quantum computing simply",
                  chatProvider,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion, ChatProvider chatProvider) {
    return ActionChip(
      label: Text(suggestion),
      onPressed: () {
        _messageController.text = suggestion;
        _sendMessage();
      },
      // Use theme's chip style
      backgroundColor: Theme.of(context).chipTheme.backgroundColor,
      labelStyle: Theme.of(context).chipTheme.labelStyle,
      shape: Theme.of(context).chipTheme.shape,
      padding: Theme.of(context).chipTheme.padding,
    );
  }

  // --- Input Area Widget ---
  Widget _buildInputArea(
    BuildContext context,
    ChatProvider chatProvider,
    ThemeData theme,
  ) {
    final isFantasy =
        Provider.of<ThemeProvider>(context, listen: false).isFantasyMode;

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File attachment preview if any
            if (chatProvider.attachedFile != null)
              Container(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: theme.iconTheme.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatProvider.attachedFile!.path
                            .split(Platform.pathSeparator)
                            .last,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => chatProvider.clearAttachedFile(),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment Button
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: theme.iconTheme.color?.withOpacity(0.8),
                  ),
                  tooltip: "Attach File",
                  onPressed:
                      chatProvider.isLoading
                          ? null
                          : () => chatProvider.pickAndSendFile(
                            sendImmediately: false,
                          ),
                ),

                // Text Input Field (Flexible)
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 200, // Maximum height for 7 lines
                    ),
                    decoration: BoxDecoration(
                      color: theme.inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(isFantasy ? 20 : 8),
                      border: Border.all(
                        color:
                            _textFocusNode.hasFocus
                                ? theme.colorScheme.primary
                                : theme.inputDecorationTheme.fillColor ??
                                    Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: Scrollbar(
                      controller: _textScrollController,
                      child: TextField(
                        controller: _messageController,
                        focusNode: _textFocusNode,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        scrollController: _textScrollController,
                        style: theme.textTheme.bodyMedium,
                        onSubmitted: (text) {
                          if (Platform.isWindows) {
                            // On Windows, Enter creates new line, Ctrl+Enter sends
                            if (text.contains('\n')) {
                              _sendMessage();
                            }
                          } else {
                            _sendMessage();
                          }
                        },
                        onChanged: (text) {
                          // Update button state based on text content
                          final hasText = text.trim().isNotEmpty;
                          if (hasText != _hasText) {
                            setState(() {
                              _hasText = hasText;
                            });
                            if (hasText) {
                              _buttonAnimationController.forward();
                            } else {
                              _buttonAnimationController.reverse();
                            }
                          }
                        },
                        decoration: InputDecoration(
                          hintText: "Ask anything...",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send / Record Button
                if (chatProvider.isLoading)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _buttonAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_buttonAnimationController.value * 0.2),
                        child: GestureDetector(
                          onTapDown: (_) => _handleRecordButtonPress(),
                          onTapUp: (_) => _handleRecordButtonRelease(),
                          onTapCancel: () {
                            if (_isRecording) {
                              setState(() {
                                _isRecording = false;
                              });
                              chatProvider.stopAndSendRecording();
                            }
                          },
                          child: Tooltip(
                            message:
                                _hasText
                                    ? "Send message"
                                    : (_isRecording
                                        ? "Release to send recording"
                                        : "Hold to Record"),
                            child: Material(
                              color: theme.colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _hasText ? _sendMessage : null,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Icon(
                                    _hasText
                                        ? Icons.send
                                        : (_isRecording
                                            ? Icons.stop
                                            : Icons.mic),
                                    color: theme.colorScheme.onPrimary,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
