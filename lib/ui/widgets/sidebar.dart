import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/conversation.dart';
import '../pages/settings_page.dart'; // Import settings page

class Sidebar extends StatelessWidget {
  final double width;
  const Sidebar({Key? key, this.width = 260}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    final isFantasy = themeProvider.isFantasyMode;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Column(
        children: [
          // Header (Optional: Add app logo or fixed branding)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(
                    isFantasy
                        ? Icons.auto_awesome
                        : Icons.insights, // Fantasy icon vs standard
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "AI Assistant",
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),

          // New Chat Button
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 16.0,
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                chatProvider.createNewConversation();
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text("New Chat"),
              style: theme.elevatedButtonTheme.style?.copyWith(
                minimumSize: WidgetStateProperty.all(
                  const Size(double.infinity, 45),
                ),
              ),
            ),
          ),

          // Conversation History List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemCount: chatProvider.conversations.length,
              itemBuilder: (context, index) {
                final conversation = chatProvider.conversations[index];
                final bool isSelected =
                    index == chatProvider.currentConversationIndex;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6.0),
                  decoration: BoxDecoration(
                    // Use theme's selection color mechanism if available, otherwise manual
                    color:
                        isSelected
                            ? theme.listTileTheme.selectedTileColor ??
                                theme.highlightColor
                            : Colors.transparent,
                    borderRadius:
                        theme.listTileTheme.shape is RoundedRectangleBorder
                            ? (theme.listTileTheme.shape
                                        as RoundedRectangleBorder)
                                    .borderRadius
                                as BorderRadius?
                            : BorderRadius.circular(
                              8,
                            ), // Default if shape isn't rounded
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: theme.listTileTheme.iconColor,
                    ),
                    title: Text(
                      conversation.title.isEmpty
                          ? "Chat ${conversation.id.substring(0, 4)}..."
                          : conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.listTileTheme.titleTextStyle?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat(
                        'MMM d, yyyy',
                      ).format(conversation.lastUpdatedAt), // Show date
                      style: theme.listTileTheme.subtitleTextStyle,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.redAccent.withOpacity(0.7),
                      ),
                      tooltip: "Delete Conversation",
                      onPressed:
                          () => _confirmDeleteConversation(
                            context,
                            chatProvider,
                            conversation.id,
                          ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    onTap: () {
                      chatProvider.selectConversation(index);
                    },
                    selected: isSelected,
                    dense: true,
                    shape: theme.listTileTheme.shape, // Apply theme shape
                  ),
                );
              },
            ),
          ),

          Divider(color: theme.dividerColor, height: 1),

          // Settings and Theme Toggle Buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Column(
              // Use column for multiple footer items
              children: [
                ListTile(
                  leading: Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: theme.iconTheme.color?.withOpacity(0.8),
                  ),
                  title: Text("Settings", style: theme.textTheme.bodyMedium),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage()),
                    );
                  },
                  dense: true,
                ),
                ListTile(
                  leading: Icon(
                    isFantasy
                        ? Icons.nightlight_round
                        : Icons.flare_outlined, // Toggle icons
                    size: 20,
                    color: theme.iconTheme.color?.withOpacity(0.8),
                  ),
                  title: Text(
                    isFantasy ? "Dark Mode" : "Fantasy Mode",
                    style: theme.textTheme.bodyMedium,
                  ),
                  onTap: () {
                    themeProvider.toggleFantasyTheme();
                  },
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteConversation(
    BuildContext context,
    ChatProvider chatProvider,
    String conversationId,
  ) {
    // Ensure we're trying to delete the currently selected one for safety, or adjust logic
    if (chatProvider.currentConversation?.id != conversationId &&
        chatProvider.conversations.any((c) => c.id == conversationId)) {
      // Find the index if it's not the current one
      final indexToDelete = chatProvider.conversations.indexWhere(
        (c) => c.id == conversationId,
      );
      if (indexToDelete != -1) {
        chatProvider.selectConversation(
          indexToDelete,
        ); // Select it first to delete safely
      } else
        return; // Should not happen if ID exists
    } else if (chatProvider.currentConversation?.id != conversationId) {
      return; // Trying to delete something not selectable? Abort.
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Delete Conversation?"),
          content: Text(
            "Are you sure you want to permanently delete this chat history? This cannot be undone.",
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text("Delete", style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
                chatProvider.deleteCurrentConversation(); // Perform deletion
              },
            ),
          ],
        );
      },
    );
  }
}
