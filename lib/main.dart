import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/report_provider.dart';
import 'providers/location_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/report_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'services/storage_service.dart';
import 'screens/report_detail_screen.dart';

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Debug print for loaded environment variables
  print("API_BASE_URL: ${dotenv.env['API_BASE_URL']}");
  print("REPORTING_AGENT_URL: ${dotenv.env['REPORTING_AGENT_URL']}");
  
  // Initialize local storage
  final storageService = StorageService();
  await storageService.init();
  
  runApp(MyApp(storageService: storageService));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;
  
  const MyApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(storageService: storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReportProvider>(
          create: (context) => ReportProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previous) => 
            previous!..updateAuth(auth),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'TL Waste Monitoring',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            initialRoute: SplashScreen.routeName,
            routes: {
              // Define all routes here for navigation
              SplashScreen.routeName: (context) => const SplashScreen(),
              LoginScreen.routeName: (context) => const LoginScreen(),
              RegisterScreen.routeName: (context) => const RegisterScreen(),
              HomeScreen.routeName: (context) => const HomeScreen(),
              ReportScreen.routeName: (context) => const ReportScreen(),
              MapScreen.routeName: (context) => const MapScreen(), // Will show back button
              ProfileScreen.routeName: (context) => const ProfileScreen(), // Will show back button
              ReportDetailScreen.routeName: (context) => ReportDetailScreen(
                reportId: ModalRoute.of(context)!.settings.arguments as int,),
            },
            // If route not found in the routes map
            onGenerateRoute: (settings) {
              print("Navigating to undefined route: ${settings.name}");
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: Center(
                    child: Text('Route ${settings.name} not found!'),
                  ),
                ),
              );
            },
            onUnknownRoute: (settings) {
              // Fallback for routes that don't exist - go to home screen
              return MaterialPageRoute(
                builder: (_) => const HomeScreen(),
              );
            },
          );
        },
      ),
    );
  }
}