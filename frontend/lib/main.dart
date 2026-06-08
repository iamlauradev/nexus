import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'theme/rpg_theme.dart';
import 'services/auth_provider.dart';
import 'services/theme_provider.dart';
import 'utils/responsive.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/media_list_screen.dart';
import 'screens/catalog_hub_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/add_entry_screen.dart';
import 'screens/rating_config_screen.dart';
import 'screens/search_screen.dart';
import 'screens/import_export_screen.dart';
import 'screens/profile_screen.dart';

class EntryChangeNotifier extends ChangeNotifier {
  void entryAdded() => notifyListeners();
}

// ---------------------------------------------------------------------------
// Router — declared once, refreshes on auth change
// ---------------------------------------------------------------------------

GoRouter _makeRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (ctx, state) {
      if (auth.loading || auth.serverUnreachable) return null;
      final onLogin = state.matchedLocation == '/login';
      if (!auth.isLogged && !onLogin) return '/login';
      if (auth.isLogged && onLogin) return '/home';
      return null;
    },
    refreshListenable: auth,
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) => NoTransitionPage(child: _ShellScaffold(shell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/catalog',
              pageBuilder: (_, state) => _fadePage(state, const CatalogHubScreen()),
              routes: [
                GoRoute(
                  path: 'media',
                  pageBuilder: (_, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final types = extra?['types'] as List<String>?;
                    final label = (extra?['label'] as String?) ?? 'Catálogo';
                    return CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: Scaffold(
                        backgroundColor: RpgColors.obsidian,
                        appBar: AppBar(title: Text(label)),
                        body: MediaListScreen(types: types, sectionLabel: label),
                      ),
                      transitionDuration: const Duration(milliseconds: 220),
                      transitionsBuilder: (_, anim, __, child) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.04, 0),
                            end: Offset.zero,
                          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim),
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (_, state) => _fadePage(state, const SearchScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (_, state) => _fadePage(state, const ProfileScreen()),
            ),
          ]),
        ],
      ),
    ],
  );
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

// ---------------------------------------------------------------------------
// App entry
// ---------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF7F1D1D),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            'ERROR: ${details.exceptionAsString()}\n\n${details.stack}',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
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
        ChangeNotifierProvider(create: (_) => EntryChangeNotifier()),
      ],
      child: const NexusApp(),
    ),
  );
}

class NexusApp extends StatefulWidget {
  const NexusApp({super.key});
  @override
  State<NexusApp> createState() => _NexusAppState();
}

class _NexusAppState extends State<NexusApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_router == null) {
      final auth = context.read<AuthProvider>();
      _router = _makeRouter(auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return MaterialApp.router(
      title: 'Nexus',
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      routerConfig: _router!,
      builder: (ctx, child) {
        final auth = context.watch<AuthProvider>();
        if (auth.loading) return const _SplashScreen();
        if (auth.serverUnreachable) {
          return _ConnectionErrorScreen(onRetry: auth.init);
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

class _ConnectionErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _ConnectionErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: Color(0xFF7C6FEB), size: 56),
            const SizedBox(height: 20),
            const Text('Sin conexión al servidor',
                style: TextStyle(
                  color: Color(0xFFF4F1FF),
                  fontFamily: 'DMSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                )),
            const SizedBox(height: 8),
            const Text('Comprueba que el servidor está activo',
                style: TextStyle(
                  color: Color(0xFF8B84B0),
                  fontFamily: 'DMSans',
                  fontSize: 13,
                )),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C6FEB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF09080F), Color(0xFF0F0D1A)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline, color: Color(0xFF7C6FEB), size: 64),
              SizedBox(height: 20),
              Text('NEXUS', style: TextStyle(
                fontFamily: 'Cinzel', fontSize: 32,
                color: Color(0xFFF4F1FF), letterSpacing: 5,
                fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Tu colección multimedia', style: TextStyle(
                color: Color(0xFF8B84B0), fontFamily: 'DMSans', fontSize: 13,
                letterSpacing: 0.3)),
              SizedBox(height: 44),
              CircularProgressIndicator(color: Color(0xFF7C6FEB), strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4-tab navigation shell
// ---------------------------------------------------------------------------

class _NavTab {
  final String label;
  final IconData icon;
  final IconData iconActive;
  const _NavTab(this.label, this.icon, this.iconActive);
}

const _tabs = [
  _NavTab('Inicio',   Icons.home_outlined,           Icons.home),
  _NavTab('Catálogo', Icons.grid_view_outlined,       Icons.grid_view),
  _NavTab('Buscar',   Icons.search_outlined,          Icons.search),
  _NavTab('Perfil',   Icons.account_circle_outlined,  Icons.account_circle),
];

class _ShellScaffold extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ShellScaffold({required this.shell});

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktop;
    final idx = shell.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && idx != 0) {
          shell.goBranch(0, initialLocation: true);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        centerTitle: !isDesktop,
        title: Text('NEXUS'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (ctx, tp, _) => IconButton(
              icon: Icon(tp.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              onPressed: tp.toggle,
              tooltip: 'Cambiar tema',
            ),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart_outlined,
                color: RpgColors.textMuted, size: 20),
            onPressed: () => Navigator.push(context,
                _slideRoute(const StatsScreen())),
            tooltip: 'Estadísticas',
          ),
          IconButton(
            icon: Icon(Icons.download_outlined,
                color: RpgColors.textMuted, size: 20),
            onPressed: () => Navigator.push(context,
                _slideRoute(const ImportExportScreen())),
            tooltip: 'Importar / Exportar',
          ),
          IconButton(
            icon: Icon(Icons.tune_outlined,
                color: RpgColors.textMuted, size: 20),
            onPressed: () => Navigator.push(context,
                _slideRoute(const RatingConfigScreen())),
            tooltip: 'Configurar valoraciones',
          ),
          IconButton(
            icon: Icon(Icons.logout_outlined,
                color: RpgColors.textMuted, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.read<AuthProvider>().logout();
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: isDesktop
          ? Row(children: [
              _DesktopSidebar(
                selectedIndex: idx,
                onTabSelected: (i) => shell.goBranch(i),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: shell),
            ])
          : shell,
      floatingActionButton: idx == 1
          ? FloatingActionButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Navigator.push(
                  context,
                  _slideRoute(const AddEntryScreen(
                    initialType: 'MOVIE',
                    availableTypes: [
                      'MOVIE', 'DORAMA', 'SERIES',
                      'MANGA', 'MANHWA', 'MANHUA', 'WEBTOON', 'ANIME', 'NOVEL',
                    ],
                  )),
                );
                if (context.mounted) {
                  context.read<EntryChangeNotifier>().entryAdded();
                }
              },
              backgroundColor: RpgColors.goldDark,
              child: Icon(Icons.add, color: RpgColors.goldLight),
            )
          : null,
      bottomNavigationBar: isDesktop
          ? null
          : _MobileNav(
              selectedIndex: idx,
              onTap: (i) {
                HapticFeedback.selectionClick();
                shell.goBranch(i,
                    initialLocation: i == shell.currentIndex);
              },
            ),
    ),
    );
  }
}

PageRoute<T> _slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.0, 0.04),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Bottom navigation bar
// ---------------------------------------------------------------------------

class _MobileNav extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTap;
  const _MobileNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: RpgColors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onTap,
        selectedFontSize: 9,
        unselectedFontSize: 9,
        iconSize: 22,
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.iconActive),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop sidebar
// ---------------------------------------------------------------------------

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final void Function(int) onTabSelected;
  const _DesktopSidebar(
      {required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Container(
      width: 200,
      color: RpgColors.darkVoid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info badge
          if (auth.user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: RpgColors.goldDark,
                  backgroundImage: auth.user!.avatarUrl != null
                      ? NetworkImage(auth.user!.avatarUrl!)
                      : null,
                  child: auth.user!.avatarUrl == null
                      ? Icon(Icons.person, size: 16, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        auth.user!.displayName ?? auth.user!.username,
                        style: TextStyle(
                          fontSize: 11,
                          color: RpgColors.textPrimary, fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        '@${auth.user!.username}',
                        style: TextStyle(
                          fontSize: 10, color: RpgColors.textMuted,
                          overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          Divider(height: 1),
          SizedBox(height: 8),
          // Main tabs
          for (var i = 0; i < _tabs.length; i++)
            _SidebarItem(
              tab: _tabs[i],
              isSelected: i == selectedIndex,
              onTap: () => onTabSelected(i),
            ),
          Divider(height: 1),
          // Extra shortcuts
          _SidebarItem(
            tab: const _NavTab(
                'Estadísticas', Icons.bar_chart_outlined, Icons.bar_chart),
            isSelected: false,
            onTap: () => Navigator.push(
                context, _slideRoute(const StatsScreen())),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final _NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;
  const _SidebarItem(
      {required this.tab, required this.isSelected, required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? RpgColors.accent.withOpacity(0.15)
                : _hovered
                    ? RpgColors.surface.withOpacity(0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(
              widget.isSelected ? widget.tab.iconActive : widget.tab.icon,
              color: widget.isSelected ? RpgColors.accent : RpgColors.textMuted,
              size: 18,
            ),
            SizedBox(width: 12),
            Text(
              widget.tab.label,
              style: TextStyle(
                fontFamily: 'Crimson', fontSize: 14,
                color: widget.isSelected ? RpgColors.accent : RpgColors.textMuted,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
