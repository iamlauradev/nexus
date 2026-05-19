import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/rpg_theme.dart';
import 'services/auth_provider.dart';
import 'services/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/media_list_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/add_entry_screen.dart';
import 'screens/rating_config_screen.dart';
import 'screens/search_screen.dart';
import 'screens/import_export_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show real errors instead of silent gray screens in release builds
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF7F1D1D),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            'ERROR: ${details.exceptionAsString()}\n\n${details.stack}',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const NexusApp(),
    ),
  );
}

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Nexus',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.isDark ? AppTheme.dark() : AppTheme.light(),
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.loading) {
                return Scaffold(
                  backgroundColor: const Color(0xFF0A0E1A),
                  body: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0F1629), Color(0xFF0A0E1A)],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_outline, color: Color(0xFF8B5CF6), size: 72),
                          const SizedBox(height: 16),
                          const Text('NEXUS', style: TextStyle(
                            fontFamily: 'Cinzel', fontSize: 32, color: Colors.white, letterSpacing: 4)),
                          const SizedBox(height: 8),
                          const Text('Media Tracker', style: TextStyle(
                            color: Color(0xFF94A3B8), fontFamily: 'Crimson', fontSize: 16)),
                          const SizedBox(height: 40),
                          const CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (!auth.isLogged) return const LoginScreen();
              return const MainShell();
            },
          ),
        );
      },
    );
  }
}

// Definición de secciones del catálogo
class _Section {
  final String label;
  final List<String> types;
  final IconData icon;
  final IconData iconActive;

  const _Section(this.label, this.types, this.icon, this.iconActive);
}

const _catalogSections = [
  _Section('Películas', ['MOVIE'],   Icons.movie_outlined,       Icons.movie),
  _Section('Doramas',   ['DORAMA'],  Icons.live_tv_outlined,     Icons.live_tv),
  _Section('Series',    ['SERIES'],  Icons.tv_outlined,          Icons.tv),
  _Section('Cómics',    ['MANGA', 'MANHWA', 'MANHUA', 'WEBTOON', 'NOVEL'],
                                     Icons.auto_stories_outlined, Icons.auto_stories),
  _Section('Anime',     ['ANIME'],   Icons.animation_outlined,   Icons.animation),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  // idx 0 = Home, idx 1-5 = catalog sections, idx 6 = Stats
  late final List<Widget> _pages = [
    const HomeScreen(),
    ..._catalogSections.map((s) => MediaListScreen(types: s.types, sectionLabel: s.label)),
    const StatsScreen(),
  ];

  bool get _isCatalog => _idx >= 1 && _idx <= _catalogSections.length;

  _Section? get _currentSection =>
      _isCatalog ? _catalogSections[_idx - 1] : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEXUS'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (ctx, tp, _) => IconButton(
              icon: Icon(tp.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: tp.toggle,
              tooltip: 'Cambiar tema',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: RpgColors.textMuted, size: 20),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SearchScreen())),
            tooltip: 'Buscar',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: RpgColors.textMuted, size: 20),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ImportExportScreen())),
            tooltip: 'Importar / Exportar',
          ),
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: RpgColors.textMuted, size: 20),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RatingConfigScreen())),
            tooltip: 'Configurar valoraciones',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: RpgColors.textMuted, size: 20),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen())),
            tooltip: 'Mi perfil',
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: RpgColors.textMuted, size: 20),
            onPressed: () => context.read<AuthProvider>().logout(),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(index: _idx, children: _pages),
      floatingActionButton: _isCatalog
          ? FloatingActionButton(
              onPressed: () {
                final section = _currentSection!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEntryScreen(
                      initialType: section.types.first,
                      availableTypes: section.types,
                    ),
                  ),
                );
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
          selectedFontSize: 9,
          unselectedFontSize: 9,
          iconSize: 22,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            ..._catalogSections.map((s) => BottomNavigationBarItem(
              icon: Icon(s.icon),
              activeIcon: Icon(s.iconActive),
              label: s.label,
            )),
            const BottomNavigationBarItem(
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
