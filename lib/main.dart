import 'package:flutter/material.dart';
import 'package:insaat_takip/screens/login_screen.dart';
import 'package:insaat_takip/screens/register_screen.dart';
import 'package:insaat_takip/screens/home_screen.dart';
import 'package:insaat_takip/screens/profile_screen.dart';
import 'package:insaat_takip/screens/project_screen.dart';
import 'package:insaat_takip/screens/floor_screen.dart';
import 'package:insaat_takip/screens/element_screen.dart';
import 'package:insaat_takip/screens/projects_screen.dart';
import 'package:insaat_takip/services/supabase_service.dart';
import 'package:insaat_takip/utils/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase istemcisini başlat
  await SupabaseService.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isRegisterRoute = state.matchedLocation == '/register';
      
      // Kullanıcı giriş yapmışsa ve login/register sayfalarındaysa, ana sayfaya yönlendir
      if (isLoggedIn && (isLoginRoute || isRegisterRoute)) {
        return '/home';
      }
      
      // Kullanıcı giriş yapmamışsa ve korunan bir sayfaya erişmeye çalışıyorsa, login sayfasına yönlendir
      if (!isLoggedIn && !isLoginRoute && !isRegisterRoute) {
        return '/login';
      }
      
      // Yönlendirme gerekmiyorsa null dön
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/project/:id',
        builder: (context, state) => ProjectScreen(
          projectId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/floor/:id',
        builder: (context, state) => FloorScreen(
          floorId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/element/:id',
        builder: (context, state) => ElementScreen(
          elementId: state.pathParameters['id'] ?? '',
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'İnşaat Takip',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
