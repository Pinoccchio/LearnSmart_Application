import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../models/activity.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-refresh when tab is switched to (deferred until after build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().refreshStudyStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Tracker'),
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          final stats = appProvider.studyStats;
          
          // Handle loading state
          if (stats.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.bgPrimary),
                  SizedBox(height: 16),
                  Text(
                    'Loading your study analytics...',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Handle error state
          if (stats.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load Statistics',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stats.errorMessage ?? 'Something went wrong',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => appProvider.refreshStudyStats(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bgPrimary,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }
          
          // Handle empty state
          if (stats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Study Data Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start studying with any of our techniques to see your progress here!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to My Courses tab
                      context.read<AppProvider>().setCurrentIndex(1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bgPrimary,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Start Studying'),
                  ),
                ],
              ),
            );
          }
          
          // Handle data state - show the actual tracker content
          return RefreshIndicator(
            onRefresh: () => appProvider.refreshStudyStats(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Time spent by technique',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                
                // Quick stats row
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStat(
                        'Consistency',
                        '${stats.consistency}%',
                        Icons.trending_up,
                        AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStat(
                        'Total Time',
                        stats.totalTime,
                        Icons.schedule,
                        AppColors.bgPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStat(
                        'Top Technique',
                        stats.topTechnique,
                        Icons.star,
                        AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Pie Chart
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 60,
                      sections: _buildPieChartSections(stats.techniqueUsage),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Technique breakdown
                const Text(
                  'Technique Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...stats.techniqueUsage.map((usage) {
                  return TechniqueListItem(
                    usage: usage,
                    onTap: () {
                      _showTechniqueDetails(context, usage);
                    },
                  );
                }),
                
                // Show unused techniques
                if (stats.techniqueUsage.length < 4) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Techniques to Explore',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._getUnusedTechniques(stats.techniqueUsage).map((technique) {
                    return UnusedTechniqueItem(
                      techniqueName: technique['name'],
                      description: technique['description'],
                      icon: technique['icon'],
                      color: technique['color'],
                      onTap: () {
                        _showTechniqueDetails(context, TechniqueUsage(
                          technique: technique['name'],
                          percentage: 0.0,
                          timesUsed: 0,
                          color: technique['color'],
                        ));
                      },
                    );
                  }),
                ],
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(List<TechniqueUsage> techniqueUsage) {
    return techniqueUsage.map((usage) {
      // For very small percentages, don't show text to avoid overcrowding
      final shouldShowTitle = usage.percentage >= 5.0;
      
      return PieChartSectionData(
        color: usage.color,
        value: usage.percentage,
        title: shouldShowTitle ? '${usage.percentage.toInt()}%' : '',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
        // Add subtle border for small sections to make them more visible
        borderSide: usage.percentage < 3.0 
          ? BorderSide(color: AppColors.white, width: 1)
          : BorderSide.none,
      );
    }).toList();
  }

  void _showTechniqueDetails(BuildContext context, TechniqueUsage usage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with technique icon and color
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: usage.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTechniqueIcon(usage.technique),
                  color: usage.color,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                usage.technique,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildDialogStatCard(
                      'Usage',
                      '${usage.percentage.toStringAsFixed(1)}%',
                      Icons.pie_chart,
                      usage.color,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDialogStatCard(
                      'Sessions',
                      '${usage.timesUsed}',
                      Icons.timeline,
                      usage.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.warning,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getTechniqueDescription(usage.technique),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: usage.color,
                    side: BorderSide(color: usage.color),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTechniqueIcon(String technique) {
    switch (technique.toLowerCase()) {
      case 'active recall':
        return Icons.psychology;
      case 'pomodoro':
        return Icons.timer;
      case 'feynman technique':
        return Icons.record_voice_over;
      case 'retrieval practice':
        return Icons.quiz;
      default:
        return Icons.school;
    }
  }

  String _getTechniqueDescription(String technique) {
    switch (technique.toLowerCase()) {
      case 'active recall':
        return 'This technique strengthens memory by actively retrieving information from your mind. Great for long-term retention and understanding!';
      case 'pomodoro':
        return 'Time-blocking technique that improves focus through structured work sessions with regular breaks. Perfect for maintaining concentration!';
      case 'feynman technique':
        return 'Learning by teaching - explain concepts in simple terms to identify knowledge gaps. Excellent for deep understanding!';
      case 'retrieval practice':
        return 'Strengthens memory through varied practice questions and spaced repetition. Ideal for exam preparation and skill building!';
      default:
        return 'This technique has been effective for your learning style. Keep using it for better retention and understanding!';
    }
  }

  List<Map<String, dynamic>> _getUnusedTechniques(List<TechniqueUsage> usedTechniques) {
    final allTechniques = [
      {
        'name': 'Active Recall',
        'description': 'Test knowledge from memory',
        'icon': Icons.psychology,
        'color': const Color(0xFF10B981),
      },
      {
        'name': 'Pomodoro',
        'description': 'Focus with timed sessions',
        'icon': Icons.timer,
        'color': const Color(0xFF3B82F6),
      },
      {
        'name': 'Feynman Technique',
        'description': 'Learn by teaching others',
        'icon': Icons.record_voice_over,
        'color': const Color(0xFFEF4444),
      },
      {
        'name': 'Retrieval Practice',
        'description': 'Spaced repetition quizzes',
        'icon': Icons.quiz,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    final usedTechniqueNames = usedTechniques.map((t) => t.technique).toSet();
    return allTechniques.where((t) => !usedTechniqueNames.contains(t['name'])).toList();
  }
}

class TechniqueListItem extends StatelessWidget {
  final TechniqueUsage usage;
  final VoidCallback onTap;

  const TechniqueListItem({
    super.key,
    required this.usage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: usage.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usage.technique,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${usage.timesUsed} times this week',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${usage.percentage.toInt()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: usage.color,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UnusedTechniqueItem extends StatelessWidget {
  final String techniqueName;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const UnusedTechniqueItem({
    super.key,
    required this.techniqueName,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      techniqueName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Try it',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withValues(alpha: 0.7),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}