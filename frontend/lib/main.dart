import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/rpg_theme.dart';
import 'services/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/media_list_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/add_entry_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: const NexusApp(),
    ),
  );
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus',
      debugShowCheckedModeBanner: false,
      theme: buildRpgTheme(),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: RpgColors.gold)),
            );
          }
          if (!auth.isLogged) return const LoginScreen();
          return const MainShell();
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  final _pages = const [
    HomeScreen(),
    MediaListScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚔', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            const Text('CHRONICLES'),
            const SizedBox(width: 8),
            const Text('⚔', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: RpgColors.textMuted, size: 20),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(index: _idx, children: _pages),
      floatingActionButton: _idx == 1
        ? FloatingActionButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEntryScreen()));
            },
            backgroundColor: RpgColors.goldDark,
            child: const Icon(Icons.add, color: RpgColors.goldLight),
          )
        : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: RpgColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _idx,
          onTap: (i) => setState(() => _idx = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: 'Catálogo',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}
