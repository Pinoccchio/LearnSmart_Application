import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/study_analytics_models.dart';

class PerformanceChartWidget extends StatelessWidget {
  final PerformanceMetrics performanceMetrics;
  final bool showDetails;

  const PerformanceChartWidget({
    super.key,
    required this.performanceMetrics,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.barChart3,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Performance Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Pre vs Post Comparison Chart
          _buildAccuracyComparisonChart(),
          
          if (showDetails) ...[
            const SizedBox(height: 20),
            
            // Performance Metrics Grid
            _buildPerformanceMetricsGrid(),
            
            const SizedBox(height: 16),
            
            // Material Performance Breakdown
            if (performanceMetrics.materialPerformance.isNotEmpty)
              _buildMaterialPerformanceSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildAccuracyComparisonChart() {
    final preAccuracy = performanceMetrics.preStudyAccuracy;
    final postAccuracy = performanceMetrics.postStudyAccuracy;
    final improvement = performanceMetrics.improvementPercentage;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Title
          const Text(
            'Learning Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Chart visualization
          Row(
            children: [
              // Pre-study bar
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Pre-Study',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Background bar
                          Container(
                            width: 40,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          // Filled bar
                          Container(
                            width: 40,
                            height: (120 * (preAccuracy / 100)).clamp(0, 120),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          // Percentage label
                          Positioned(
                            bottom: (120 * (preAccuracy / 100)).clamp(0, 120) + 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${preAccuracy.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow and improvement
              Column(
                children: [
                  Icon(
                    improvement > 0 
                        ? LucideIcons.arrowUp
                        : improvement < 0
                            ? LucideIcons.arrowDown
                            : LucideIcons.minus,
                    color: improvement > 0 
                        ? Colors.green 
                        : improvement < 0 
                            ? Colors.red 
                            : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: improvement > 0 
                          ? Colors.green 
                          : improvement < 0 
                              ? Colors.red 
                              : Colors.grey,
                    ),
                  ),
                ],
              ),
              
              // Post-study bar
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Post-Study',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Background bar
                          Container(
                            width: 40,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          // Filled bar
                          Container(
                            width: 40,
                            height: (120 * (postAccuracy / 100)).clamp(0, 120),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          // Percentage label
                          Positioned(
                            bottom: (120 * (postAccuracy / 100)).clamp(0, 120) + 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${postAccuracy.toInt()}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Metrics grid
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Response Time',
                  '${performanceMetrics.averageResponseTime.toStringAsFixed(1)}s',
                  LucideIcons.clock,
                  _getResponseTimeColor(performanceMetrics.averageResponseTime),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricItem(
                  'Performance Level',
                  _formatPerformanceLevel(performanceMetrics.overallLevel),
                  LucideIcons.target,
                  _getPerformanceLevelColor(performanceMetrics.overallLevel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialPerformanceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Material Performance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Material performance bars
          ...performanceMetrics.materialPerformance.entries
              .take(5) // Limit to top 5 materials
              .map((entry) => _buildMaterialPerformanceBar(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildMaterialPerformanceBar(String materialName, double accuracy) {
    final color = accuracy >= 80 
        ? Colors.green 
        : accuracy >= 60 
            ? Colors.orange 
            : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  materialName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${accuracy.toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: (accuracy / 100).clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getResponseTimeColor(double responseTime) {
    if (responseTime < 15) return Colors.green;
    if (responseTime < 30) return Colors.orange;
    return Colors.red;
  }

  Color _getPerformanceLevelColor(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.excellent:
        return Colors.green;
      case PerformanceLevel.good:
        return Colors.blue;
      case PerformanceLevel.average:
        return Colors.orange;
      case PerformanceLevel.needsImprovement:
        return Colors.red;
      case PerformanceLevel.poor:
        return Colors.red[700]!;
    }
  }

  String _formatPerformanceLevel(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.excellent:
        return 'Excellent';
      case PerformanceLevel.good:
        return 'Good';
      case PerformanceLevel.average:
        return 'Average';
      case PerformanceLevel.needsImprovement:
        return 'Needs Work';
      case PerformanceLevel.poor:
        return 'Poor';
    }
  }
}