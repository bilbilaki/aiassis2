import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart'; // To access providers if needed (like Theme)
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p; // For path manipulation
import 'package:open_file/open_file.dart'; // To open files

import '../../models/chat_message.dart';
import '../../providers/theme_provider.dart'; // Access theme colors

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final ChatMessage? previousMessage; // To check if sender is the same

  const MessageBubble({Key? key, required this.message, this.previousMessage})
    : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  AudioPlayer? _audioPlayer;
  PlayerState? _playerState;
  Duration? _duration;
  Duration? _position;
  bool _isPlaying = false;
  bool _showDetails = false; // For long press or tap

  @override
  void initState() {
    super.initState();
    if (widget.message.type == MessageType.audio &&
        widget.message.filePath != null) {
      _initAudioPlayer();
    }
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    // Set release mode to keep player alive longer if needed, or loop if needed
    // await _audioPlayer?.setReleaseMode(ReleaseMode.loop);

    _audioPlayer?.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
        });
      }
    });

    _audioPlayer?.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer?.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer?.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _position = Duration.zero; // Reset position on completion
          _isPlaying = false;
        });
      }
    });

    // Prepare the player but don't play yet
    try {
      await _audioPlayer?.setSource(DeviceFileSource(widget.message.filePath!));
      // Optionally get duration here if needed before playing
      _duration = await _audioPlayer?.getDuration();
      setState(() {}); // Update UI with duration if available
    } catch (e) {
      print("Error setting audio source: $e");
      // Handle error (e.g., show an error icon in the player)
    }
  }

  @override
  void dispose() {
    _audioPlayer?.release(); // Release player resources
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_audioPlayer == null) return;

    if (_playerState == PlayerState.playing) {
      await _audioPlayer?.pause();
      setState(() => _isPlaying = false);
    } else {
      try {
        // Need to handle potential errors if file doesn't exist or is corrupt
        if (widget.message.filePath != null &&
            await File(widget.message.filePath!).exists()) {
          print("Playing: ${widget.message.filePath}");
          Source source = DeviceFileSource(widget.message.filePath!);
          await _audioPlayer?.play(source);
          setState(() => _isPlaying = true);
        } else {
          print("Audio file not found: ${widget.message.filePath}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: Audio file not found.')),
          );
        }
      } catch (e) {
        print("Error playing audio: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: ${e.toString()}')),
        );
        setState(() => _isPlaying = false); // Ensure state is correct on error
      }
    }
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    final bool isUser = widget.message.isUser;
    final bool isSameSenderAsPrevious =
        widget.previousMessage != null &&
        widget.previousMessage!.isUser == isUser;
    final bool isFantasy =
        themeProvider.isFantasyMode; // Check for fantasy theme

    // Use fantasy-specific colors if needed
    final userBubbleColor =
        isFantasy
            ? theme.colorScheme.primary.withOpacity(0.4)
            : theme.colorScheme.primary;
    final aiBubbleColor =
        isFantasy
            ? theme.colorScheme.surface
            : theme
                .colorScheme
                .surface; // Use surface for AI in both themes for consistency? Or specific fantasy color
    final userTextColor =
        isFantasy
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onPrimary; // Adjust if needed
    final aiTextColor =
        isFantasy ? theme.colorScheme.onSurface : theme.colorScheme.onSurface;

    return GestureDetector(
      onLongPress: () {
        setState(() {
          _showDetails = !_showDetails;
        });
      },
      onTap: () {
        if (_showDetails) {
          setState(() {
            _showDetails = false; // Hide details on tap if shown
          });
        }
        // Handle taps on media if needed (e.g., fullscreen image)
      },
      child: Container(
        margin: EdgeInsets.only(
          bottom:
              isSameSenderAsPrevious ? 4.0 : 16.0, // Less space if same sender
          left: isUser ? 40.0 : 16.0, // Indent user messages more
          right: isUser ? 16.0 : 40.0, // Indent AI messages more
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Optional: Show sender name/icon only for first message in a sequence
            if (!isSameSenderAsPrevious)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                      size: 16,
                      color: theme.iconTheme.color?.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isUser
                          ? "You"
                          : widget.message.modelUsed ?? "AI Assistant",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.textTheme.labelSmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main content bubble
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment:
                  CrossAxisAlignment.end, // Align icons with bottom
              children: [
                // Action Buttons (like copy) - Show before bubble for AI, after for User
                if (!isUser) _buildActionButtons(context, theme),
                if (!isUser) const SizedBox(width: 8),

                Flexible(
                  // Ensure bubble doesn't overflow
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? userBubbleColor : aiBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16.0),
                        topRight: const Radius.circular(16.0),
                        bottomLeft: Radius.circular(
                          isUser ? 16.0 : (isSameSenderAsPrevious ? 16.0 : 4.0),
                        ), // Pointy corner for first message
                        bottomRight: Radius.circular(
                          isUser ? (isSameSenderAsPrevious ? 16.0 : 4.0) : 16.0,
                        ), // Pointy corner for first message
                      ),
                      boxShadow:
                          isFantasy
                              ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    isUser ? 0.2 : 0.1,
                                  ),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ]
                              : null, // Subtle shadow for fantasy theme
                    ),
                    child: SelectableRegion(
                      // Makes text inside selectable
                      focusNode: FocusNode(), // Required for SelectableRegion
                      selectionControls:
                          MaterialTextSelectionControls(), // Use platform controls
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- Render Media ---
                          if (widget.message.type == MessageType.image &&
                              widget.message.filePath != null)
                            _buildImageContent(context),
                          if (widget.message.type == MessageType.audio &&
                              widget.message.filePath != null)
                            _buildAudioContent(context, theme),
                          if (widget.message.type == MessageType.file &&
                              widget.message.filePath != null)
                            _buildFileContent(context, theme),

                          // --- Render Text (caption or main message) ---
                          // Only show text if it's not empty OR if it's the only content type
                          if (widget.message.text.isNotEmpty ||
                              widget.message.type == MessageType.text)
                            Padding(
                              padding: EdgeInsets.only(
                                top: widget.message.isMedia ? 6.0 : 0,
                              ), // Add space above text if media exists
                              child: _buildTextContent(
                                context,
                                theme,
                                isUser ? userTextColor : aiTextColor,
                              ),
                            ),

                          // --- Show Timestamp/Details on long press ---
                          if (_showDetails)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM d, hh:mm a').format(
                                  widget.message.timestamp,
                                ), // Format timestamp
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: (isUser ? userTextColor : aiTextColor)
                                      .withOpacity(0.6),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons for User Messages
                if (isUser) const SizedBox(width: 8),
                if (isUser) _buildActionButtons(context, theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Content Building Widgets ---

  Widget _buildTextContent(
    BuildContext context,
    ThemeData theme,
    Color textColor,
  ) {
    return MarkdownBody(
      data: widget.message.text,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: GoogleFonts.firaCode().fontFamily,
          backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
          color: textColor,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.canvasColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onTapLink: (text, href, title) {
        print('Tapped link: $href');
      },
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final File imageFile = File(widget.message.filePath!);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
        maxHeight: 300,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          imageFile,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 100,
              color: Colors.grey.shade300,
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.grey.shade600),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAudioContent(BuildContext context, ThemeData theme) {
    final fileExists =
        widget.message.filePath != null &&
        File(widget.message.filePath!).existsSync();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color:
                  theme.colorScheme.primary, // Use primary color for controls
            ),
            onPressed:
                fileExists
                    ? _playPause
                    : null, // Disable if file doesn't seem to exist
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          const SizedBox(width: 8),
          if (_duration != null) // Show slider only if duration is known
            Expanded(
              child: Slider(
                value: (_position ?? Duration.zero).inMilliseconds
                    .toDouble()
                    .clamp(0.0, (_duration!).inMilliseconds.toDouble()),
                min: 0.0,
                max: (_duration!).inMilliseconds.toDouble(),
                onChanged:
                    fileExists
                        ? (value) async {
                          final position = Duration(
                            milliseconds: value.toInt(),
                          );
                          await _audioPlayer?.seek(position);
                          // Optional: Resume playing after seek
                          // if (!_isPlaying) {
                          //   await _playPause();
                          // }
                        }
                        : null,
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.primary.withOpacity(0.3),
              ),
            )
          else // Show placeholder if duration isn't loaded yet
            Expanded(
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary.withOpacity(0.3),
                ),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          if (widget.message.filePath !=
              null) // Download/Open button for audio file
            IconButton(
              icon: Icon(
                Icons.download_for_offline_outlined,
                size: 18,
                color: theme.iconTheme.color?.withOpacity(0.7),
              ),
              onPressed: () => _openOrDownloadFile(context),
              tooltip: "Open File",
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 24, minHeight: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildFileContent(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () => _openOrDownloadFile(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Keep row tight
          children: [
            Icon(
              _getFileIcon(widget.message.fileName),
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Flexible(
              // Prevent long filenames from overflowing
              child: Text(
                widget.message.fileName ?? "Attached File",
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_for_offline_outlined,
              size: 18,
              color: theme.iconTheme.color?.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  // --- Actions and Helpers ---
  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          <Widget>[
                IconButton(
                  icon: Icon(Icons.copy_all_outlined, size: 18),
                  tooltip: 'Copy text',
                  onPressed:
                      widget.message.text.isNotEmpty
                          ? () {
                            Clipboard.setData(
                              ClipboardData(text: widget.message.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Text copied to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                          : null, // Disable if no text
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                if (widget.message.filePath != null &&
                    widget
                        .message
                        .isMedia) // Show download only for received/sent media
                  IconButton(
                    icon: Icon(Icons.download_outlined, size: 18),
                    tooltip: 'Download/Open File',
                    onPressed: () => _openOrDownloadFile(context),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                // Add other actions like thumbs up/down if needed
                // IconButton(icon: Icon(Icons.thumb_up_outlined, size: 18), onPressed: () {}, padding: EdgeInsets.zero, constraints: BoxConstraints()),
              ]
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: e,
                ),
              )
              .toList(), // Add slight spacing
    );
  }

  Future<void> _openOrDownloadFile(BuildContext context) async {
    if (widget.message.filePath == null) return;
    try {
      final result = await OpenFile.open(widget.message.filePath!);
      print("OpenFile result: ${result.type} - ${result.message}");
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      print("Error opening file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${e.toString()}')),
      );
    }
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file_outlined;
    final extension = p.extension(fileName).toLowerCase();
    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.doc':
      case '.docx':
        return Icons.description_outlined; // Word doc icon
      case '.xls':
      case '.xlsx':
        return Icons.table_chart_outlined; // Excel icon
      case '.ppt':
      case '.pptx':
        return Icons.slideshow_outlined; // PowerPoint icon
      case '.zip':
      case '.rar':
      case '.7z':
        return Icons.archive_outlined;
      case '.txt':
        return Icons.text_snippet_outlined;
      case '.mp3':
      case '.wav':
      case '.m4a':
        return Icons.audio_file_outlined;
      case '.mp4':
      case '.mov':
      case '.avi':
        return Icons.video_file_outlined;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
} // End of _MessageBubbleState
