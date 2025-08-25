import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractionService {
  static const int maxContentLength = 8000; // Limit for AI processing
  static const int maxRetries = 3;
  
  /// Extracts text content from a PDF file URL
  Future<String> extractTextFromPdfUrl(String pdfUrl) async {
    try {
      print('📄 [PDF EXTRACTION] Starting extraction from: ${pdfUrl.substring(0, 50)}...');
      
      // Download PDF file
      final pdfBytes = await _downloadPdfFile(pdfUrl);
      if (pdfBytes == null) {
        throw Exception('Failed to download PDF file');
      }
      
      // Extract text from PDF bytes
      final extractedText = await _extractTextFromBytes(pdfBytes);
      
      // Process and clean the extracted text
      final processedText = _processExtractedText(extractedText);
      
      print('✅ [PDF EXTRACTION] Successfully extracted ${processedText.length} characters');
      return processedText;
      
    } catch (e) {
      print('❌ [PDF EXTRACTION] Failed to extract text: $e');
      rethrow;
    }
  }
  
  /// Downloads PDF file from URL with retry logic
  Future<Uint8List?> _downloadPdfFile(String url) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        print('📥 [PDF DOWNLOAD] Attempt $attempts/$maxRetries');
        
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'LearnSmart-App/1.0',
            'Accept': 'application/pdf',
          },
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          print('✅ [PDF DOWNLOAD] Downloaded ${response.bodyBytes.length} bytes');
          return response.bodyBytes;
        } else {
          print('⚠️ [PDF DOWNLOAD] HTTP ${response.statusCode}: ${response.reasonPhrase}');
          if (attempts == maxRetries) {
            throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
          }
        }
      } catch (e) {
        print('❌ [PDF DOWNLOAD] Attempt $attempts failed: $e');
        if (attempts == maxRetries) {
          rethrow;
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: attempts * 2));
      }
    }
    
    return null;
  }
  
  /// Extracts text from PDF bytes using Syncfusion
  Future<String> _extractTextFromBytes(Uint8List pdfBytes) async {
    try {
      // Load the PDF document from bytes
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      
      // Extract text from all pages
      String extractedText = '';
      
      // Get page count
      final int pageCount = document.pages.count;
      print('📖 [PDF PARSING] Processing $pageCount pages');
      
      // Extract text page by page
      for (int i = 0; i < pageCount; i++) {
        try {
          final String pageText = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
          extractedText += pageText;
          extractedText += '\n\n'; // Add page separator
          
          print('📄 [PDF PARSING] Page ${i + 1}/$pageCount: ${pageText.length} characters');
          
          // Break early if we have enough content
          if (extractedText.length > maxContentLength * 2) {
            print('⚠️ [PDF PARSING] Content limit reached, stopping at page ${i + 1}');
            break;
          }
        } catch (e) {
          print('⚠️ [PDF PARSING] Failed to extract text from page ${i + 1}: $e');
          // Continue with other pages
        }
      }
      
      // Dispose the document to free memory
      document.dispose();
      
      if (extractedText.trim().isEmpty) {
        throw Exception('No text content found in PDF. Document may be image-based or corrupted.');
      }
      
      print('✅ [PDF PARSING] Total extracted: ${extractedText.length} characters');
      return extractedText;
      
    } catch (e) {
      print('❌ [PDF PARSING] Text extraction failed: $e');
      rethrow;
    }
  }
  
  /// Processes and cleans extracted text for AI consumption
  String _processExtractedText(String rawText) {
    if (rawText.trim().isEmpty) {
      return 'No readable text content found in this PDF document.';
    }
    
    // Clean and process the text
    String processedText = rawText;
    
    // Remove excessive whitespace and normalize line breaks
    processedText = processedText.replaceAll(RegExp(r'\s+'), ' ');
    processedText = processedText.replaceAll(RegExp(r'\n+'), '\n');
    
    // Remove common PDF artifacts
    processedText = processedText.replaceAll(RegExp(r'[^\x20-\x7E\n]'), ' '); // Keep only printable ASCII + newlines
    processedText = processedText.replaceAll(RegExp(r'\s+'), ' '); // Collapse multiple spaces
    
    // Trim to reasonable length for AI processing
    if (processedText.length > maxContentLength) {
      processedText = _truncateIntelligently(processedText, maxContentLength);
      print('✂️ [PDF PROCESSING] Truncated content to ${processedText.length} characters');
    }
    
    // Final cleanup
    processedText = processedText.trim();
    
    if (processedText.isEmpty) {
      return 'PDF content could not be extracted or processed properly.';
    }
    
    return processedText;
  }
  
  /// Intelligently truncates text to preserve sentence boundaries
  String _truncateIntelligently(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    
    // Try to cut at sentence boundaries
    final sentences = text.split(RegExp(r'[.!?]+'));
    String result = '';
    
    for (final sentence in sentences) {
      final potential = result.isEmpty ? sentence : '$result. $sentence';
      if (potential.length > maxLength) {
        break;
      }
      result = potential;
    }
    
    // If no good sentence boundary found, do word-based truncation
    if (result.isEmpty || result.length < maxLength * 0.7) {
      final words = text.split(' ');
      result = '';
      
      for (final word in words) {
        final potential = result.isEmpty ? word : '$result $word';
        if (potential.length > maxLength) {
          break;
        }
        result = potential;
      }
    }
    
    return result.isNotEmpty ? result : text.substring(0, maxLength);
  }
  
  /// Checks if a URL points to a PDF file
  bool isPdfUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    final path = uri.path.toLowerCase();
    return path.endsWith('.pdf') || 
           path.contains('.pdf?') || 
           path.contains('.pdf#');
  }
  
  /// Gets a sample of the extracted content for preview
  String getSampleContent(String fullContent, {int sampleLength = 200}) {
    if (fullContent.length <= sampleLength) {
      return fullContent;
    }
    
    final sample = fullContent.substring(0, sampleLength);
    final lastSpace = sample.lastIndexOf(' ');
    
    if (lastSpace > sampleLength * 0.8) {
      return '${sample.substring(0, lastSpace)}...';
    }
    
    return '$sample...';
  }
}