import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  final String chatId;

  const HomePage({super.key, required this.chatId});

  @override
  _HomePageState createState() => _HomePageState();
}

class Message {
  final String text;
  final bool isUser; // true for user, false for AI

  Message({required this.text, required this.isUser});
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _textController = TextEditingController();
  List<String> _messages = [];
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;

  void _handleSubmitted(String text) {
    _textController.clear();
    setState(() { // This block remains unchanged
      _messages.insert(0, text);
    });
    _saveMessages(); // Save messages after adding a new one
    // TODO: Integrate AI bot response
  }

  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    await Permission.speech.request();
     if (micStatus != PermissionStatus.granted) {
 await Permission.storage.request();
      throw RecordingPermissionException('Microphone permission not granted');
    }
  }

  @override
  void initState() {
    super.initState();
 _requestPermissions();
    _initRecorder();
    _loadMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
    _recorder?.closeRecorder();
    _recorder = null;
  }

  Future<void> _initRecorder() async {
     await _requestPermissions();
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  Future<void> _startRecording() async {
     if (_recorder == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';
     await _recorder!.startRecorder(toFile: filePath, codec: Codec.aacMP4);
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    if (_recorder == null || !_isRecording) return;
    final filePath = await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    print('Recorded file: $filePath');
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _messages = prefs.getStringList('chat_${widget.chatId}') ?? [];
    });
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('chat_${widget.chatId}', _messages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Display the chat ID in the app bar for now
        title: Text('Chat ID: ${widget.chatId}'),
        backgroundColor:Color.fromARGB(255, 0, 180, 14), // Added background color
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String result) {
              // TODO: Implement actions for each menu item
              switch (result) {
                case 'Settings':
                // Navigate to settings page
                  break;
                case 'Profile':
                // Navigate to profile page
                  break;
                case 'Logout':
                // Perform logout
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'Settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem<String>(value: 'Profile', child: Text('Profile')),
              const PopupMenuItem<String>(value: 'Logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // This block remains unchanged
          Flexible(
            child: ListView.builder(
              padding: EdgeInsets.all(8.0),
              reverse: true,
              // Assuming messages are stored as String and need conversion back to Message objects
              itemBuilder: (_, int index) => _buildMessage(
                // In a real app, you would determine if the message is from the user or bot
                Message(text: _messages[index], isUser: index % 2 == 0), // Example: alternate for demonstration
              ),
              itemCount: _messages.length,
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(), // This line remains unchanged
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Message messageBlock) { // This line remains unchanged
    // Determine if the message is from the user or the AI (you'll need to adjust this logic
    // when you integrate the AI bot)
    final bool isUser = messageBlock.isUser;
    final messageText = messageBlock.text; // For now, assume all messages are from the user

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser ? Color.fromARGB(255,  181, 215, 167) : Colors.grey[300],
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    messageText,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(25.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                    hintText: 'Send a message'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _handleSubmitted(_textController.text), // This line remains unchanged
              ),
            // Placeholder for Speech-to-Text
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: Icon(
                _isRecording ? Icons.stop_circle : Icons.mic,
                color: _isRecording ? Colors.red : null,
                ),
            ),
          ],
        ),
      ),
    );
  }
}
