import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import 'home/home_screen.dart';
import 'modules/my_courses_screen.dart';
import 'course_catalog/course_catalog_screen.dart';
import 'tracker/tracker_screen.dart';
import 'activities/activities_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  VoidCallback? _refreshMyCoursesCallback;
  bool _isInitialized = false;

  void _setMyCoursesRefreshCallback(VoidCallback callback) {
    _refreshMyCoursesCallback = callback;
  }

  void _refreshMyCourses() {
    _refreshMyCoursesCallback?.call();
  }

  @override
  void initState() {
    super.initState();
    // Initialize AppProvider when MainScreen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAppProvider();
    });
  }

  Future<void> _initializeAppProvider() async {
    if (!_isInitialized) {
      print('🚀 [MAIN SCREEN] ========================================');
      print('🚀 [MAIN SCREEN] Starting AppProvider initialization...');
      print('🚀 [MAIN SCREEN] Timestamp: ${DateTime.now().toIso8601String()}');

      try {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        await appProvider.initialize();

        print('✅ [MAIN SCREEN] AppProvider initialized successfully');
        setState(() {
          _isInitialized = true;
        });
      } catch (e, stackTrace) {
        print('❌ [MAIN SCREEN] ========================================');
        print('❌ [MAIN SCREEN] ERROR during initialization');
        print('❌ [MAIN SCREEN] Error: $e');
        print('❌ [MAIN SCREEN] Stack trace: $stackTrace');

        // Still mark as initialized to show error state instead of loading forever
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        // Show loading screen during initialization
        if (!_isInitialized) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.bgPrimary,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Loading your learning experience...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait while we fetch your data',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: appProvider.currentIndex,
            children: [
              const HomeScreen(),
              MyCoursesScreen(
                onRegisterRefresh: _setMyCoursesRefreshCallback,
              ),
              CourseCatalogScreen(onCourseEnrolled: _refreshMyCourses),
              const TrackerScreen(),
              const ActivitiesScreen(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: appProvider.currentIndex,
              onTap: appProvider.setCurrentIndex,
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.white,
              selectedItemColor: AppColors.bgPrimary,
              unselectedItemColor: AppColors.textSecondary,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.home),
                  activeIcon: Icon(LucideIcons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.bookOpen),
                  activeIcon: Icon(LucideIcons.bookOpen),
                  label: 'My Courses',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.search),
                  activeIcon: Icon(LucideIcons.search),
                  label: 'Browse',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.barChart3),
                  activeIcon: Icon(LucideIcons.barChart3),
                  label: 'Tracker',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.activity),
                  activeIcon: Icon(LucideIcons.activity),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(LucideIcons.user),
                  activeIcon: Icon(LucideIcons.user),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}