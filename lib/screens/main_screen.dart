import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/app_colors.dart';
import '../providers/app_provider.dart';
import 'home/home_screen.dart';
import 'modules/modules_screen.dart';
import 'tracker/tracker_screen.dart';
import 'activities/activities_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return Scaffold(
          body: IndexedStack(
            index: appProvider.currentIndex,
            children: const [
              HomeScreen(),
              ModulesScreen(),
              TrackerScreen(),
              ActivitiesScreen(),
              ProfileScreen(),
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
                  label: 'Modules',
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