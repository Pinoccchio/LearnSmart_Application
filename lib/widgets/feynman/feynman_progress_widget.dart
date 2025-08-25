import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/feynman_models.dart';
import '../../services/feynman_service.dart';

class FeynmanProgressWidget extends StatelessWidget {
  final FeynmanService feynmanService;

  const FeynmanProgressWidget({
    super.key,
    required this.feynmanService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feynmanService,
      builder: (context, child) {
        final session = feynmanService.currentSession;
        final explanations = feynmanService.sessionExplanations;
        
        if (session == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
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
                      color: _getStatusColor(session.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(session.status),
                      color: _getStatusColor(session.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feynmanService.currentPhaseTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.topic,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSessionTimer(session),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Phase description
              Text(
                feynmanService.currentPhaseDescription,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              
              if (explanations.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildExplanationProgress(explanations),
              ],
              
              if (session.status != FeynmanSessionStatus.completed) ...[
                const SizedBox(height: 16),
                _buildPhaseSteps(session),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionTimer(FeynmanSession session) {
    final duration = session.isCompleted 
        ? session.totalDuration 
        : DateTime.now().difference(session.startedAt);
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.clock,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationProgress(List<FeynmanExplanation> explanations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Explanation Attempts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${explanations.length}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Explanation timeline
        Column(
          children: explanations.asMap().entries.map((entry) {
            final index = entry.key;
            final explanation = entry.value;
            final isLast = index == explanations.length - 1;
            
            return _buildExplanationItem(explanation, index + 1, isLast);
          }).toList(),
        ),
        
        // Average score if available
        if (explanations.any((e) => e.overallScore != null)) ...[
          const SizedBox(height: 16),
          _buildScoreSummary(explanations),
        ],
      ],
    );
  }

  Widget _buildExplanationItem(FeynmanExplanation explanation, int attemptNumber, bool isLast) {
    final hasScore = explanation.overallScore != null;
    final score = explanation.overallScore ?? 0.0;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: explanation.isProcessed && hasScore
                    ? _getScoreColor(score)
                    : explanation.isProcessing
                        ? Colors.blue
                        : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: explanation.isProcessing
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        attemptNumber.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (!isLast) ...[
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.shade300,
              ),
            ],
          ],
        ),
        
        const SizedBox(width: 12),
        
        // Explanation details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Attempt $attemptNumber',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasScore)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getScoreColor(score).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${score.toStringAsFixed(1)}/10',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score),
                        ),
                      ),
                    )
                  else if (explanation.isProcessing)
                    const Text(
                      'Analyzing...',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    const Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              Text(
                '${explanation.wordCount} words • ${_formatTime(explanation.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
              
              if (explanation.strengths.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: explanation.strengths.take(2).map((strength) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        strength,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green.shade700,
                          height: 1.2,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              SizedBox(height: isLast ? 0 : 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreSummary(List<FeynmanExplanation> explanations) {
    final scoredExplanations = explanations.where((e) => e.overallScore != null);
    if (scoredExplanations.isEmpty) return const SizedBox.shrink();
    
    final avgScore = scoredExplanations
        .map((e) => e.overallScore!)
        .reduce((a, b) => a + b) / scoredExplanations.length;
    
    final improvement = explanations.length > 1 && 
                       explanations.first.overallScore != null && 
                       explanations.last.overallScore != null
        ? explanations.last.overallScore! - explanations.first.overallScore!
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  avgScore.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(avgScore),
                  ),
                ),
                const Text(
                  'Average Score',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          if (improvement != 0.0) ...[
            Container(
              width: 1,
              height: 30,
              color: AppColors.grey300,
            ),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        improvement > 0 ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                        size: 16,
                        color: improvement > 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${improvement > 0 ? '+' : ''}${improvement.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: improvement > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Improvement',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseSteps(FeynmanSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.compass,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Next Steps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Column(
            children: _getNextSteps(session).map((step) => _buildStepItem(step)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              step,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getNextSteps(FeynmanSession session) {
    switch (session.status) {
      case FeynmanSessionStatus.preparing:
        return [
          'Start by explaining the topic in your own words',
          'Don\'t worry about perfection - just begin',
          'Use simple language and examples',
        ];
      case FeynmanSessionStatus.explaining:
        return [
          'Continue improving your explanation',
          'Add more examples and analogies',
          'Identify areas you\'re unsure about',
          'Submit when you feel ready for feedback',
        ];
      case FeynmanSessionStatus.reviewing:
        return [
          'Review the AI feedback carefully',
          'Address any identified gaps',
          'Try explaining again with improvements',
          'Complete when satisfied with your understanding',
        ];
      case FeynmanSessionStatus.completed:
      case FeynmanSessionStatus.paused:
        return [];
    }
  }

  Color _getStatusColor(FeynmanSessionStatus status) {
    switch (status) {
      case FeynmanSessionStatus.preparing:
        return Colors.orange;
      case FeynmanSessionStatus.explaining:
        return Colors.blue;
      case FeynmanSessionStatus.reviewing:
        return Colors.purple;
      case FeynmanSessionStatus.completed:
        return Colors.green;
      case FeynmanSessionStatus.paused:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(FeynmanSessionStatus status) {
    switch (status) {
      case FeynmanSessionStatus.preparing:
        return LucideIcons.settings;
      case FeynmanSessionStatus.explaining:
        return LucideIcons.edit;
      case FeynmanSessionStatus.reviewing:
        return LucideIcons.search;
      case FeynmanSessionStatus.completed:
        return LucideIcons.checkCircle;
      case FeynmanSessionStatus.paused:
        return LucideIcons.pause;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 6.0) return Colors.blue;
    if (score >= 4.0) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}