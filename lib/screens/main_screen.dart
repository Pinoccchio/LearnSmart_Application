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
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.initialize();
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
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