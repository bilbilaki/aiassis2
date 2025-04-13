import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http; // Import http

// Import Providers
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';

// Import Services
import 'services/api_service.dart';
import 'services/input_service.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';

// Import UI
import 'ui/pages/chat_page.dart';
import 'ui/themes/app_themes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  // Create instances of services
  // HttpClient is created once and passed around or use a singleton pattern
  final httpClient = http.Client();
  final settingsService = SettingsService();
  final storageService = StorageService();
  final inputService = InputService();
  final apiService = ApiService(httpClient, settingsService, storageService);


  runApp(
    MultiProvider(
      providers: [
         ChangeNotifierProvider(create: (_) => ThemeProvider()),
         ChangeNotifierProvider(
            create: (_) => ChatProvider(apiService, inputService, storageService, settingsService),
            // Optionally load initial data here if needed before UI builds
            // lazy: false, // Consider if initial data load is critical
          ),
         // Add other providers if needed
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Consume the ThemeProvider to dynamically set the theme
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'AI Chat Assistant',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme, // Use the theme from the provider
      home: ChatPage(), // Start with the ChatPage
    );
  }
}