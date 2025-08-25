How to analyse files using Gemini with Flutter
Suesi Tran
Suesi Tran

Follow
5 min read
·
Feb 20, 2025
3




Introduction
In the previous post, How to Integrate Gemini with Flutter for Text-Only Prompts, we explored how to use Gemini AI in a Flutter app to generate responses from text-based prompts. We covered how to set up the Google Generative AI package, configure the Gemini API Key, and send text queries to the model.

Now, we’ll take it a step further. What if we want Gemini to analyse files? 🤔

In this tutorial, we’ll integrate file upload functionality into our Flutter app, allowing users to upload documents, images, or other files and have Gemini process them. This means you could, for example:
✅ Upload a text file and ask Gemini to translate it.
✅ Upload an image and ask Gemini to describe what’s in it.
✅ Upload a PDF and ask Gemini to summarise its content.

We’ll cover:
📌 How to let users select and upload files in a Flutter app.
📌 How to send files to Gemini for processing.
📌 How to handle Gemini’s response and display results.

By the end of this guide, you’ll be able to integrate file-based prompts into your Gemini-powered Flutter app. 🚀

Let’s get started! 💡

Implementation
Step 1: Select and Upload a File
To allow users to upload files, we’ll use the file_picker package in Flutter. This will enable users to pick files from their device and send them to Gemini for processing.

1️⃣ Add file_picker to pubspec.yaml
First, install the package by adding it to your dependencies:

flutter pub add file_picker
2️⃣ Implement File Selection in Flutter
We’ll create a new FileService, with function to let users select a file:

import 'package:file_picker/file_picker.dart';

// export PlatformFile to be used in main.dart
export 'package:file_picker/file_picker.dart' show PlatformFile;

class FileService {
  Future<PlatformFile?> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
  
    if (result != null) {
      return result.files.single; // Return the selected file
    }
    return null; // No file selected
  }
}
This function opens the file picker and returns the selected file.

3️⃣ Update the UI to Trigger File Selection
Now, we update the code from part 1, to add a button to allow users to pick a file:

import 'package:flutter/material.dart';
import 'services/gemini_service.dart';
import 'services/file_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: GeminiChatScreen(),
    );
  }
}

class GeminiChatScreen extends StatefulWidget {
  const GeminiChatScreen({super.key});

  @override
  _GeminiChatScreenState createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends State<GeminiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final FileService _fileService = FileService();

  List<String> _messages = [];

  void _sendPrompt() async {
    final prompt = _controller.text;
    if (prompt.isNotEmpty) {
      setState(() {
        _messages.add("You: $prompt");
        _messages.add("AI: Thinking...");
      });

      final result = await _geminiService.sendMessage(prompt);

      setState(() {
        _messages[_messages.length - 1] = "AI: $result"; // Update AI response
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gemini AI Chat")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_messages[index]),
                  );
                },
              ),
            ),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Enter your prompt",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _sendPrompt,
              child: const Text("Send"),
            ),
            /// add new button to open File Picker
            ElevatedButton(
              onPressed: () async {
                PlatformFile? file = await _fileService.pickFile();
                if (file != null) {
                  String prompt = _controller.text;  // Get the user-defined prompt from the TextField
                  _controller.clear(); // clear current text after sent

                  setState(() {
                    _messages.add("You: $prompt, file: ${file.name}");
                    _messages.add("AI: Thinking...");
                  });

                  // Proceed to upload
                  String response = await _geminiService.uploadFileToGemini(file, prompt);  // Upload the file and prompt

                  // update UI
                  setState(() {
                    _messages[_messages.length - 1] = "AI: $result"; // Update AI response
                  });
                }
              },
              child: Text("Select File"),
            )
          ],
        ),
      ),
    );
  }
}
Once the user picks a file, we’ll send it to Gemini in Step 3! 😎🔥

Step 3: Sending the File to Gemini using Google Generative AI
In this step, we will upload the file using the Google Generative AI API with the Content object. We’ll send both the prompt and the selected file together to Gemini for processing.

1️⃣ Add mime package to parse file’s mimeType
We will need to use mime package to parse file’s mimeType, so that we can use it in DataPart for Gemini content. DataPart is better than FilePart because it is not platform dependent on File system.

flutter pub add mime
2️⃣ Create new function in GeminiService to upload File
Now, we will add new function in file gemini_service.dart, to upload file to Gemini

import 'package:mime/mime.dart';
  
Future<String> uploadFileToGemini(PlatformFile file, String prompt) async {
    final String mimeType = lookupMimeType(file.xFile.path) ?? 'application/octet-stream';
    final Uint8List bytes = await file.xFile.readAsBytes();
    final content = Content('user', [
      TextPart(prompt),  // Add the user-defined prompt
      DataPart(mimeType, bytes),  // Add the selected file
    ]);

    try {
      final response = await _chatSession.sendMessage(
        content,
      );

        // Process the response, you can display it or handle it as needed
        print('Response: ${response.text}');

        return response.text ?? 'No response from AI.';
    } catch (e) {
      print('Error: $e');
      return 'Error: ${e.toString()}';
    }
  }
3️⃣ Trigger the File Upload after File Selection
Once the user selects a file and provides a prompt, we call this function to upload both to Gemini

ElevatedButton(
  onPressed: () async {
    PlatformFile? file = await _fileService.pickFile();
    if (file != null) {
      String prompt = _controller.text;  // Get the user-defined prompt from the TextField
      await _geminiService.uploadFileToGemini(file, prompt);  // Upload the file and prompt 
      _controller.clear(); // clear current text after sent
    }
  },
  child: Text("Select File"),
)
4️⃣ Update UI to upload file, and show response text from Gemini

We just need to update UI a little bit, so that we can update UI with Gemini’s response.

/// add new button to open File Picker
ElevatedButton(
  onPressed: () async {
    PlatformFile? file = await _fileService.pickFile();
    if (file != null) {
      String prompt = _controller.text;  // Get the user-defined prompt from the TextField
      _controller.clear(); // clear current text after sent

      setState(() {
        _messages.add("You: $prompt, file: ${file.name}");
        _messages.add("AI: Thinking...");
      });

      String response = await _geminiService.uploadFileToGemini(file, prompt);  // Upload the file and prompt
      setState(() {
        _messages[_messages.length - 1] = "AI: $response"; // Update AI response
      });
    }
  },
   child: Text("Select File"),
)
Conclusion
In this post, we’ve learned how to integrate Google Gemini into your Flutter app to handle file uploads and prompts. Here’s a recap of what we covered:

File Selection: We added functionality to select files from the user’s device.
File Upload: We used Google Generative AI’s API to upload the file along with a user-defined prompt.
Processing Files: Gemini processed the file based on the provided prompt and returned the response.
This is just the beginning! In Part 3, we’ll take it a step further and explore how to generate images using Gemini. We’ll walk through how to upload an image file, send it to Gemini, and handle the resulting image output.

Stay tuned for more! 🚀

Conclusion
With this integration, you’ve expanded the capabilities of your Gemini-powered Flutter app to handle file uploads. You can now send files to Gemini, have it analyze or process the content, and use the results in your app. In future posts, we will explore how to use Gemini for image generation and even integrate media into your app! If you enjoyed this post, feel free to buy me a coffee!