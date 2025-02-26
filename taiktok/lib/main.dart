import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/paper_provider.dart';
import 'services/user_provider.dart';
import 'theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('🚀 App starting...');

  if (Firebase.apps.isEmpty) {
    print('📦 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
      name: '[MyApp]',
    );
    print('✅ Firebase initialized successfully');
  }

  // Load API key for paper service
  print('🔑 Loading preferences...');
  final prefs = await SharedPreferences.getInstance();
  final apiKey = prefs.getString('geminiApiKey') ?? '';
  print('🔑 API Key loaded: ${apiKey.isNotEmpty ? 'Present' : 'Empty'}');

  // load the model
  final model = prefs.getString('model') ?? 'gemini-2.0-flash-lite';
  print('🧠 Model selected: $model');

  runApp(MyApp(apiKey: apiKey, model: model));
}

class MyApp extends StatefulWidget {
  final String apiKey;
  final String model;

  const MyApp({super.key, required this.apiKey, required this.model});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppTheme _currentTheme = AppTheme.cyberGalaxy;

  late final String _model;

  @override
  void initState() {
    super.initState();
    print('🎨 Initializing app state...');
    _loadTheme();
    _model = widget.model;
    print('🧠 Model set to: $_model');
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('theme') ?? AppTheme.cyberGalaxy.name;
    print('🎨 Loading theme: $themeName');
    setState(() {
      _currentTheme = AppTheme.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => AppTheme.cyberGalaxy,
      );
    });
  }

  Future<void> _saveTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme.name);
    print('🎨 Saved theme: ${theme.name}');
    setState(() {
      _currentTheme = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building app with providers...');

    return MultiProvider(
      providers: [
        // Provide the PaperProvider to the widget tree
        ChangeNotifierProvider(create: (_) {
          print('🧩 Creating PaperProvider instance with model: $_model');
          return PaperProvider(widget.apiKey, model: _model);
        }),
        // Provide the UserProvider to the widget tree
        ChangeNotifierProvider(create: (_) {
          print('👤 Creating UserProvider instance');
          final provider = UserProvider();
          // Initialize user state
          provider.initialize();
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'TaikTok',
        theme: AppThemes.getTheme(_currentTheme),
        home: HomeScreen(
          onThemeChanged: _saveTheme,
          currentTheme: _currentTheme,
        ),
      ),
    );
  }
}
