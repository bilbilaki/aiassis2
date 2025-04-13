// TODO Implement this library.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart'; // Access settings via ChatProvider for now
import '../../providers/theme_provider.dart'; // Access theme
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _webhookUrlController;
  late TextEditingController _systemMessageController;
  late TextEditingController _userMessageController;
  late TextEditingController _maxTokensController;
  late TextEditingController _temperatureController;
  late TextEditingController _topKController;
  late TextEditingController _topPController;
  late Map<String, String> _customMemory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _webhookUrlController = TextEditingController();
    _systemMessageController = TextEditingController();
    _userMessageController = TextEditingController();
    _maxTokensController = TextEditingController();
    _temperatureController = TextEditingController();
    _topKController = TextEditingController();
    _topPController = TextEditingController();
    _customMemory = {};
    _loadInitialSettings();
  }

  Future<void> _loadInitialSettings() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    try {
      final url = await chatProvider.getWebhookUrl();
      final systemMessage = await chatProvider.getSystemMessage();
      final userMessage = await chatProvider.getUserMessage();
      final maxTokens = await chatProvider.getMaxTokens();
      final temperature = await chatProvider.getTemperature();
      final topK = await chatProvider.getTopK();
      final topP = await chatProvider.getTopP();
      final customMemory = await chatProvider.getCustomMemory();

      if (mounted) {
        setState(() {
          _webhookUrlController.text = url;
          _systemMessageController.text = systemMessage;
          _userMessageController.text = userMessage;
          _maxTokensController.text = maxTokens.toString();
          _temperatureController.text = temperature.toString();
          _topKController.text = topK.toString();
          _topPController.text = topP.toString();
          _customMemory = customMemory;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading settings: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: ${e.toString()}')),
        );
      }
    }
  }

  void _showCustomMemoryDialog() {
    showDialog(
      context: context,
      builder:
          (context) => CustomMemoryDialog(
            initialMemory: _customMemory,
            onSave: (newMemory) {
              setState(() {
                _customMemory = newMemory;
              });
            },
          ),
    );
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    _systemMessageController.dispose();
    _userMessageController.dispose();
    _maxTokensController.dispose();
    _temperatureController.dispose();
    _topKController.dispose();
    _topPController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      try {
        await chatProvider.saveWebhookUrl(_webhookUrlController.text.trim());
        await chatProvider.saveSystemMessage(
          _systemMessageController.text.trim(),
        );
        await chatProvider.saveUserMessage(_userMessageController.text.trim());
        await chatProvider.saveMaxTokens(int.parse(_maxTokensController.text));
        await chatProvider.saveTemperature(
          double.parse(_temperatureController.text),
        );
        await chatProvider.saveTopK(int.parse(_topKController.text));
        await chatProvider.saveTopP(double.parse(_topPController.text));
        await chatProvider.saveCustomMemory(_customMemory);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        print("Error saving settings: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).currentTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Settings'), centerTitle: true),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildSectionTitle('API Configuration', theme),
                      _buildWebhookUrlField(theme),

                      _buildSectionTitle('Model Parameters', theme),
                      _buildSystemMessageField(theme),
                      _buildUserMessageField(theme),
                      _buildMaxTokensField(theme),
                      _buildTemperatureField(theme),
                      _buildTopKField(theme),
                      _buildTopPField(theme),

                      _buildSectionTitle('Custom Memory', theme),
                      _buildCustomMemoryButton(theme),

                      const SizedBox(height: 24),
                      _buildSaveButton(theme),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
      ),
    );
  }

  Widget _buildWebhookUrlField(ThemeData theme) {
    return TextFormField(
      controller: _webhookUrlController,
      decoration: InputDecoration(
        labelText: 'n8n Webhook URL',
        hintText: 'Enter the full URL for your n8n webhook',
        prefixIcon: Icon(
          Icons.link,
          color: theme.iconTheme.color?.withOpacity(0.7),
        ),
        border: theme.inputDecorationTheme.border,
        enabledBorder: theme.inputDecorationTheme.enabledBorder,
        focusedBorder: theme.inputDecorationTheme.focusedBorder,
      ),
      keyboardType: TextInputType.url,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a Webhook URL';
        }
        if (!Uri.tryParse(value)!.isAbsolute ?? true) {
          return 'Please enter a valid URL';
        }
        return null;
      },
    );
  }

  Widget _buildSystemMessageField(ThemeData theme) {
    return TextFormField(
      controller: _systemMessageController,
      decoration: InputDecoration(
        labelText: 'System Message',
        hintText: 'Enter the system message for the model',
        prefixIcon: Icon(
          Icons.message,
          color: theme.iconTheme.color?.withOpacity(0.7),
        ),
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a system message';
        }
        return null;
      },
    );
  }

  Widget _buildUserMessageField(ThemeData theme) {
    return TextFormField(
      controller: _userMessageController,
      decoration: InputDecoration(
        labelText: 'User Message',
        hintText: 'Enter the user message template',
        prefixIcon: Icon(
          Icons.person,
          color: theme.iconTheme.color?.withOpacity(0.7),
        ),
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a user message template';
        }
        return null;
      },
    );
  }

  Widget _buildMaxTokensField(ThemeData theme) {
    return TextFormField(
      controller: _maxTokensController,
      decoration: InputDecoration(
        labelText: 'Max Tokens',
        hintText: 'Enter maximum tokens (e.g., 2000)',
        prefixIcon: Icon(
          Icons.format_size,
          color: theme.iconTheme.color?.withOpacity(0.7),
        ),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter max tokens';
        }
        if (int.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildTemperatureField(ThemeData theme) {
    return TextFormField(
      controller: _temperatureController,
      decoration: InputDecoration(
        labelText: 'Temperature',
        hintText: 'Enter temperature (0.0 to 1.0)',
        prefixIcon: Icon(
          Icons.thermostat,
          color: theme.iconTheme.color?.withOpacity(0.7),
        ),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter temperature';
        }
        final temp = double.tryParse(value);
        if (temp == null || temp < 0 || temp > 1) {
          return 'Please enter a value between 0.0 and 1.0';
        }
        return null;
      },
    );
  }

  Widget _buildTopKField(ThemeData theme) {
    return TextFormField(
      controller: _topKController,
      decoration: InputDecoration(
        labelText: 'Top K',
        hintText: 'Enter top K value',
        prefixIcon: Icon(
          Icons.sort,
          color: theme.iconTheme.color?.withOpacity(0.7),
        ),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter top K value';
        }
        if (int.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildTopPField(ThemeData theme) {
    return TextFormField(
      controller: _topPController,
      decoration: InputDecoration(
        labelText: 'Top P',
        hintText: 'Enter top P value (0.0 to 1.0)',
        prefixIcon: Icon(
          Icons.percent,
          color: theme.iconTheme.color?.withOpacity(0.7),
        ),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter top P value';
        }
        final topP = double.tryParse(value);
        if (topP == null || topP < 0 || topP > 1) {
          return 'Please enter a value between 0.0 and 1.0';
        }
        return null;
      },
    );
  }

  Widget _buildCustomMemoryButton(ThemeData theme) {
    return ElevatedButton.icon(
      icon: Icon(Icons.memory),
      label: Text('Manage Custom Memory'),
      onPressed: _showCustomMemoryDialog,
      style: theme.elevatedButtonTheme.style,
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return ElevatedButton.icon(
      icon: Icon(Icons.save_alt_outlined),
      label: Text('Save Settings'),
      onPressed: _saveSettings,
      style: theme.elevatedButtonTheme.style,
    );
  }
}

class CustomMemoryDialog extends StatefulWidget {
  final Map<String, String> initialMemory;
  final Function(Map<String, String>) onSave;

  CustomMemoryDialog({required this.initialMemory, required this.onSave});

  @override
  _CustomMemoryDialogState createState() => _CustomMemoryDialogState();
}

class _CustomMemoryDialogState extends State<CustomMemoryDialog> {
  late Map<String, String> _memory;
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _memory = Map.from(widget.initialMemory);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _addMemoryItem() {
    if (_keyController.text.isNotEmpty && _valueController.text.isNotEmpty) {
      setState(() {
        _memory[_keyController.text] = _valueController.text;
        _keyController.clear();
        _valueController.clear();
      });
    }
  }

  void _removeMemoryItem(String key) {
    setState(() {
      _memory.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Custom Memory'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyController,
                    decoration: InputDecoration(labelText: 'Key'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _valueController,
                    decoration: InputDecoration(labelText: 'Value'),
                  ),
                ),
                IconButton(icon: Icon(Icons.add), onPressed: _addMemoryItem),
              ],
            ),
            SizedBox(height: 16),
            ..._memory.entries
                .map(
                  (entry) => ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _removeMemoryItem(entry.key),
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_memory);
            Navigator.of(context).pop();
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}
