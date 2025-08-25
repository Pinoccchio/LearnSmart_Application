import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';
import '../../models/pomodoro_models.dart';
import '../../services/pomodoro_service.dart';

class PomodoroNotesWidget extends StatefulWidget {
  final PomodoroService pomodoroService;

  const PomodoroNotesWidget({
    super.key,
    required this.pomodoroService,
  });

  @override
  State<PomodoroNotesWidget> createState() => _PomodoroNotesWidgetState();
}

class _PomodoroNotesWidgetState extends State<PomodoroNotesWidget> {
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.pomodoroService,
      builder: (context, child) {
        final service = widget.pomodoroService;
        final notes = service.sessionNotes;
        final canAddNotes = service.currentSession != null && 
                           !service.currentSession!.isCompleted;
        
        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with expand/collapse
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          LucideIcons.stickyNote,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Study Notes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            
                            Text(
                              '${notes.length} notes taken',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Icon(
                        _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Expanded content
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                
                // Add note section
                if (canAddNotes) _buildAddNoteSection(),
                
                const SizedBox(height: 16),
                
                // Notes list
                _buildNotesList(notes),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a note',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Note input
          TextField(
            controller: _noteController,
            focusNode: _noteFocusNode,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write your thoughts, insights, or questions...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.grey300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.bgPrimary),
              ),
              filled: true,
              fillColor: AppColors.white,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Add note buttons
          Row(
            children: [
              // Quick note button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addQuickNote,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Reflection button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addReflectionNote,
                  icon: const Icon(LucideIcons.lightbulb, size: 16),
                  label: const Text('Reflection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(List<PomodoroNote> notes) {
    if (notes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Column(
          children: [
            Icon(
              LucideIcons.fileText,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            
            const SizedBox(height: 12),
            
            const Text(
              'No notes yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            
            const SizedBox(height: 4),
            
            const Text(
              'Take notes during your study session to enhance retention',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: notes.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final note = notes[notes.length - 1 - index]; // Reverse order (newest first)
          return _buildNoteItem(note);
        },
      ),
    );
  }

  Widget _buildNoteItem(PomodoroNote note) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type and timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getNoteTypeColor(note.noteType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getNoteTypeIcon(note.noteType),
                      size: 12,
                      color: _getNoteTypeColor(note.noteType),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      note.typeDisplayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _getNoteTypeColor(note.noteType),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              Text(
                _formatTimestamp(note.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Note content
          Text(
            note.content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _addQuickNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) return;

    try {
      await widget.pomodoroService.addNote(
        content: content,
        noteType: PomodoroNoteType.studyNote,
      );
      
      _noteController.clear();
      _noteFocusNode.unfocus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add note: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addReflectionNote() async {
    final content = _noteController.text.trim();
    if (content.isEmpty) {
      // Show reflection prompts
      _showReflectionPrompts();
      return;
    }

    try {
      await widget.pomodoroService.addNote(
        content: content,
        noteType: PomodoroNoteType.reflection,
      );
      
      _noteController.clear();
      _noteFocusNode.unfocus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reflection added successfully!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add reflection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReflectionPrompts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.lightbulb, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            const Text('Reflection Prompts'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consider these questions for your reflection:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            ..._getReflectionPrompts().map(
              (prompt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $prompt'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _noteFocusNode.requestFocus();
            },
            child: const Text('Write Reflection'),
          ),
        ],
      ),
    );
  }

  List<String> _getReflectionPrompts() {
    return [
      'What key concepts did I learn in this cycle?',
      'What was challenging or confusing?',
      'How can I apply this knowledge?',
      'What questions do I still have?',
      'What study strategies worked well?',
    ];
  }

  Color _getNoteTypeColor(PomodoroNoteType type) {
    switch (type) {
      case PomodoroNoteType.studyNote:
        return Colors.blue;
      case PomodoroNoteType.reflection:
        return Colors.orange;
      case PomodoroNoteType.quizAnswer:
        return Colors.green;
    }
  }

  IconData _getNoteTypeIcon(PomodoroNoteType type) {
    switch (type) {
      case PomodoroNoteType.studyNote:
        return LucideIcons.edit3;
      case PomodoroNoteType.reflection:
        return LucideIcons.lightbulb;
      case PomodoroNoteType.quizAnswer:
        return LucideIcons.checkCircle;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}