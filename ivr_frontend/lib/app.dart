import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/app_theme.dart';
import 'config/app_router.dart';
import 'core/offline/offline_sync_host.dart';
import 'core/map/map_theme_provider.dart';
import 'core/customization/admin_customization_provider.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc()..add(AuthCheckRequested()),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final MapThemeProvider _mapThemeProvider;
  late final AdminCustomizationProvider _adminCustomizationProvider;

  @override
  void initState() {
    super.initState();
    _mapThemeProvider = MapThemeProvider();
    _mapThemeProvider.init();
    _adminCustomizationProvider = AdminCustomizationProvider();
    _adminCustomizationProvider.init();
  }

  @override
  void dispose() {
    _mapThemeProvider.dispose();
    _adminCustomizationProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final router = createRouter(authBloc);

    return ListenableBuilder(
      listenable: Listenable.merge([_mapThemeProvider, _adminCustomizationProvider]),
      builder: (context, _) {
        final theme = AppTheme.buildTheme(_adminCustomizationProvider.settings);
        return _CustomizationScope(
          provider: _adminCustomizationProvider,
          child: _MapThemeScope(
            provider: _mapThemeProvider,
            child: MaterialApp.router(
              title: 'Ooraatchi: Integrated GIS-Map & E-Tendering System',
              debugShowCheckedModeBanner: false,
              theme: theme,
              darkTheme: theme,
              themeMode: _adminCustomizationProvider.settings.themeMode == 'dark'
                  ? ThemeMode.dark
                  : (_adminCustomizationProvider.settings.themeMode == 'system'
                      ? ThemeMode.system
                      : ThemeMode.light),
              routerConfig: router,
              builder: (context, child) => OfflineSyncHost(child: child),
            ),
          ),
        );
      },
    );
  }
}

/// InheritedWidget to propagate [MapThemeProvider] down the tree
/// without requiring the `provider` package.
class _MapThemeScope extends InheritedWidget {
  final MapThemeProvider provider;

  const _MapThemeScope({
    required this.provider,
    required super.child,
  });

  @override
  bool updateShouldNotify(_MapThemeScope oldWidget) =>
      provider.currentTheme.id != oldWidget.provider.currentTheme.id;
}

/// InheritedWidget to propagate [AdminCustomizationProvider] down the tree.
class _CustomizationScope extends InheritedWidget {
  final AdminCustomizationProvider provider;

  const _CustomizationScope({
    required this.provider,
    required super.child,
  });

  @override
  bool updateShouldNotify(_CustomizationScope oldWidget) => true;
}

/// Extension on [BuildContext] to easily access the [MapThemeProvider].
extension MapThemeContext on BuildContext {
  MapThemeProvider get mapThemeProvider {
    final scope = dependOnInheritedWidgetOfExactType<_MapThemeScope>();
    assert(scope != null, 'No _MapThemeScope found in widget tree');
    return scope!.provider;
  }

  MapThemeProvider get readMapThemeProvider {
    final scope = getInheritedWidgetOfExactType<_MapThemeScope>();
    assert(scope != null, 'No _MapThemeScope found in widget tree');
    return scope!.provider;
  }
}

/// Extension on [BuildContext] to easily access the [AdminCustomizationProvider].
extension CustomizationContext on BuildContext {
  AdminCustomizationProvider get adminCustomizationProvider {
    final scope = dependOnInheritedWidgetOfExactType<_CustomizationScope>();
    assert(scope != null, 'No _CustomizationScope found in widget tree');
    return scope!.provider;
  }

  AdminCustomizationProvider get readAdminCustomizationProvider {
    final scope = getInheritedWidgetOfExactType<_CustomizationScope>();
    assert(scope != null, 'No _CustomizationScope found in widget tree');
    return scope!.provider;
  }
}

