import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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
  final _recorder = FlutterSoundRecorder();
  final TextEditingController _textController = TextEditingController();
  final _player = FlutterSoundPlayer();

  String language = "english";
  List<Message> _messages = [];
  String? _filePath;
  bool _isRecording = false;
  bool _isPlaying = false;

  void _handleSubmitted(String text) {
    _textController.clear();

    setState(() { // This block remains unchanged
      _messages.insert(0, Message(text: text, isUser: true));
    });
    _saveMessages(); // Save messages after adding a new one
    _getresponseFromAI(text);
  }

  Future<void> _requestPermissions() async {
    if (await Permission.microphone.isDenied) {
      await Permission.microphone.request();
    }
    await Permission.speech.request();
   
  }
  Future<void> _getresponseFromAI(String text) async {

      final prefs = await SharedPreferences.getInstance();
      final location = prefs.getString('location') ?? '';
      final crops = prefs.getString('crops') ?? '';
      if (location.isEmpty || crops.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set your location and crops first.')),
        );
        return;
      }

    final uri = Uri.parse('http://34.123.229.247/api/ai/chat');
    final req = http.MultipartRequest('POST', uri)
      ..fields['text'] = text
      ..fields['language'] = language
      ..fields['farmerLocation'] = location
      ..fields['farmerCrops'] = crops
      ..fields['chatHistory'] = jsonEncode([_messages
          .map((msg) => {'role': msg.isUser ? 'user' : 'model','parts': [{'text': msg.text}]})
          .toList()]);
      
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    print(resp.statusCode.toString() + resp.body);
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body);
      print(json);
      print('AI response: ${json['answer']}');

      if (json['answer'] != "") {
        setState(() {
          _messages.insert(0, Message(text: json['answer'], isUser: false));
        });
        _playMessageAudio(json['answer']);
      } else {
        print('AI response is empty');
      }
    } else {
      print('AI response failed: ${resp.statusCode} ${resp.body}');
    }
    _saveMessages(); // Save messages after adding AI response
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      // get a temporary file path
      final dir = await getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/flutter_audio_hello.aac';
      print('Recording to: $_filePath');

      // start recording
      if(await Permission.microphone.isGranted) {
        await _recorder.startRecorder(
          toFile: _filePath,
          codec: Codec.aacADTS,
          audioSource: AudioSource.microphone,
          sampleRate: 16000,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }
    } else {
      // stop recording
      Future.delayed(Duration(milliseconds: 1000), () async {
        await _recorder.stopRecorder();
        if (_filePath != null) {
          await _sendAudio(_filePath!);
        }
      });

    }
    setState(() => _isRecording = !_isRecording);
  }
   Future<void> _sendAudio(String path) async {
    print("hello");

    final uri = Uri.parse('http://34.123.229.247/api/lang/transcribe');
    final req = http.MultipartRequest('POST', uri)
      ..fields['language'] = language
      ..files.add(
        await http.MultipartFile.fromPath(
          'audio',
          path,
          contentType: MediaType('audio', 'mpeg'),
        ),
      );

    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body);
      print(json);
      print('Transcription: ${json['transcript']}');

      if(json['transcript'] != ""){
        _handleSubmitted(json['transcript']);
      }
      
    } else {
      print('Upload failed: ${resp.statusCode} ${resp.body}');
    }
  }

   Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await _player.openPlayer();
    // Optional: set audio session for iOS
  }

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _requestPermissions();
    _loadMessages();
  }

  @override
  void dispose() {
    _player.closePlayer();
    _textController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _playMessageAudio(String message) async {
    if (!_player.isOpen()) return;
    print(message);

    final uri = Uri.parse('http://34.123.229.247/api/lang/synthesize');
    final headers = {
    'Content-Type': 'application/json',
  };
  final body = jsonEncode({
    'text': message,
    'language': language,
  });
    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode != 200) {
      print('Audio synthesis failed: ${resp.statusCode} ${resp.body}');
      return;
    }
    print('Audio synthesis successful: ${resp.body}');
    final responseData = jsonDecode(resp.body);
    if (responseData['audioContent'] == null) {
      print('No audio content returned');
      return;
    }
    Uint8List audioBytes = base64Decode(responseData['audioContent']);
    await _player.startPlayer(
      fromDataBuffer: audioBytes,
      codec: Codec.aacADTS,
      whenFinished: () {
        setState(() => _isPlaying = false);
      },
    );
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final messages = prefs.getStringList('chat_${widget.chatId}') ?? [];
      _messages = messages.map((msg) {
        final decoded = jsonDecode(msg);
        return Message(text: decoded['text'], isUser: decoded['isUser']);
      }).toList();
    });
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('chat_${widget.chatId}',
        _messages.map((msg) => jsonEncode({'text': msg.text, 'isUser': msg.isUser})).toList());
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
            icon: const Icon(Icons.translate),
            tooltip: 'Select Language',
            onSelected: (String result) {
              switch (result) {
                case 'English':
                  setState(() {
                    language = "english";
                  });
                  break;
                case 'Hindi':
                  setState(() {
                    language = "hindi";
                  });
                  break;
                case 'Marathi':
                  setState(() {
                    language = "marathi";
                  });
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'English', child: Text('English')),
              const PopupMenuItem<String>(value: 'Hindi', child: Text('Hindi')),
              const PopupMenuItem<String>(value: 'Marathi', child: Text('Marathi')),
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
                _messages[index], // Example: alternate for demonstration
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
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (isUser)
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20.0),
              onPressed: () {
                _playMessageAudio(messageText);
              },
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color.fromARGB(255, 181, 215, 167)
                    : Colors.grey[300],
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
          if (!isUser)
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 20.0),
              onPressed: () {
                _playMessageAudio(messageText);
              },
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
              onLongPress: _toggleRecording,
              onLongPressUp: _toggleRecording,
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
