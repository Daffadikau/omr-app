import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/scan_history_screen.dart';
import 'screens/upload_scan_screen.dart';
import 'screens/answer_key_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const OMRApp());
}

class OMRApp extends StatelessWidget {
  const OMRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMR Grading System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScanHistoryScreen(),
    UploadScanScreen(),
    AnswerKeyListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.upload),
            selectedIcon: Icon(Icons.upload),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz),
            selectedIcon: Icon(Icons.quiz),
            label: 'Kunci',
          ),
        ],
      ),
    );
  }
}
