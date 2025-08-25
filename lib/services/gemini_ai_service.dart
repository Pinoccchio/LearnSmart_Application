import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/course_models.dart';
import '../models/active_recall_models.dart';

class GeminiAIService {
  static const String _apiKey = 'AIzaSyDyFbfNS8XwzcBtnpYY-5lovrTKH5-NXLM';
  late final GenerativeModel _model;
  
  GeminiAIService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );
  }

  Future<List<ActiveRecallFlashcard>> generateFlashcardsFromMaterials(
    List<CourseMaterial> materials,
    String moduleTitle,
  ) async {
    try {
      print('🧠 [GEMINI AI] Starting flashcard generation for ${materials.length} materials');
      
      List<ActiveRecallFlashcard> allFlashcards = [];
      
      for (int i = 0; i < materials.length; i++) {
        final material = materials[i];
        print('📄 [GEMINI AI] Processing material ${i + 1}/${materials.length}: ${material.title}');
        
        try {
          final flashcards = await _generateFlashcardsFromMaterial(material, moduleTitle);
          allFlashcards.addAll(flashcards);
          print('✅ [GEMINI AI] Generated ${flashcards.length} flashcards from ${material.title}');
        } catch (e) {
          print('⚠️ [GEMINI AI] Failed to process ${material.title}: $e');
          // Continue with other materials even if one fails
        }
      }
      
      print('🎯 [GEMINI AI] Total flashcards generated: ${allFlashcards.length}');
      return allFlashcards;
      
    } catch (e) {
      print('❌ [GEMINI AI ERROR] $e');
      rethrow;
    }
  }

  Future<List<ActiveRecallFlashcard>> _generateFlashcardsFromMaterial(
    CourseMaterial material,
    String moduleTitle,
  ) async {
    // For now, we'll generate flashcards based on material metadata
    // In a full implementation, you'd extract content from PDFs/documents
    final content = await _extractContentFromMaterial(material);
    
    final prompt = '''
You are an expert educator creating Active Recall flashcards for a module titled "$moduleTitle".

Based on this learning material:
Title: ${material.title}
Description: ${material.description ?? 'No description provided'}
File Type: ${material.fileType}
Content Context: $content

Generate exactly 5 high-quality flashcards that test key concepts. Each flashcard should promote active recall and memory retrieval.

Return your response as a valid JSON array with this exact structure:
[
  {
    "type": "fill_in_blank",
    "question": "Complete this statement: _____ is the fundamental concept that...",
    "answer": "Object-oriented programming",
    "hints": ["Think about programming paradigms", "Related to classes and objects"],
    "difficulty": "medium",
    "explanation": "Brief explanation of why this answer is correct"
  },
  {
    "type": "definition_recall",
    "question": "What is the definition of [key term]?",
    "answer": "Clear, concise definition",
    "hints": ["Think about the core characteristics", "Consider its purpose"],
    "difficulty": "easy",
    "explanation": "Why this definition is important"
  },
  {
    "type": "concept_application",
    "question": "How would you apply [concept] in a real-world scenario?",
    "answer": "Practical application example",
    "hints": ["Think about practical uses", "Consider industry examples"],
    "difficulty": "hard",
    "explanation": "Why this application works"
  }
]

Important rules:
- Use only these types: "fill_in_blank", "definition_recall", "concept_application"
- Use only these difficulty levels: "easy", "medium", "hard"
- Keep questions clear and specific
- Provide 2-3 helpful hints per flashcard
- Make answers concise but complete
- Return ONLY the JSON array, no other text
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Gemini AI');
      }

      print('🤖 [GEMINI AI] Raw response: ${responseText.substring(0, responseText.length.clamp(0, 200))}...');

      // Clean up the response to extract JSON
      String jsonText = responseText.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final List<dynamic> flashcardsJson = jsonDecode(jsonText);
      
      return flashcardsJson.asMap().entries.map((entry) {
        final index = entry.key;
        final json = entry.value as Map<String, dynamic>;
        return ActiveRecallFlashcard.fromAI(
          json,
          material.id,
          material.moduleId,
          index: index,
        );
      }).toList();

    } catch (e) {
      print('❌ [GEMINI AI] Error generating flashcards: $e');
      
      // Return fallback flashcards if AI fails
      return _getFallbackFlashcards(material);
    }
  }

  Future<String> _extractContentFromMaterial(CourseMaterial material) async {
    // For now, we'll create context based on material metadata
    // In a full implementation, you'd extract actual content from PDFs, docs, etc.
    
    String contentContext = '';
    
    switch (material.fileType.toLowerCase()) {
      case 'pdf':
        contentContext = 'PDF document containing detailed information about ${material.title}';
        break;
      case 'mp4':
      case 'avi':
      case 'mov':
        contentContext = 'Video content explaining ${material.title}';
        break;
      case 'ppt':
      case 'pptx':
        contentContext = 'Presentation slides about ${material.title}';
        break;
      case 'doc':
      case 'docx':
        contentContext = 'Document with comprehensive information on ${material.title}';
        break;
      default:
        contentContext = 'Educational material covering ${material.title}';
    }
    
    if (material.description?.isNotEmpty == true) {
      contentContext += '. ${material.description}';
    }
    
    return contentContext;
  }

  List<ActiveRecallFlashcard> _getFallbackFlashcards(CourseMaterial material) {
    // Fallback flashcards if AI generation fails
    return [
      ActiveRecallFlashcard(
        id: '${material.id}_fallback_1',
        materialId: material.id,
        moduleId: material.moduleId,
        type: FlashcardType.definitionRecall,
        question: 'What is the main topic covered in "${material.title}"?',
        answer: 'The main topic relates to the learning objectives of this module.',
        hints: ['Think about the material title', 'Consider the module context'],
        difficulty: FlashcardDifficulty.easy,
        explanation: 'This tests basic comprehension of the material topic.',
        createdAt: DateTime.now(),
      ),
      ActiveRecallFlashcard(
        id: '${material.id}_fallback_2',
        materialId: material.id,
        moduleId: material.moduleId,
        type: FlashcardType.fillInBlank,
        question: 'Complete this: "${material.title}" is important because _____.',
        answer: 'it provides essential knowledge for understanding the module concepts.',
        hints: ['Think about learning objectives', 'Consider practical applications'],
        difficulty: FlashcardDifficulty.medium,
        explanation: 'This tests understanding of the material\'s relevance.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<bool> testConnection() async {
    try {
      final response = await _model.generateContent([
        Content.text('Respond with "Connection successful" if you can read this message.')
      ]);
      
      final responseText = response.text?.toLowerCase() ?? '';
      return responseText.contains('connection successful');
    } catch (e) {
      print('❌ [GEMINI AI] Connection test failed: $e');
      return false;
    }
  }
}