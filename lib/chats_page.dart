import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart'; // Import the modified home_page.dart

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  _ChatsPageState createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  List<String> _chatIds = [];

  @override
  void initState() {
    super.initState();
    _loadChatIds();
  }

  Future<void> _loadChatIds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _chatIds = prefs.getStringList('chatIds') ?? [];
    });
  }

  Future<void> _startNewChat() async {
    final prefs = await SharedPreferences.getInstance();
    final newChatId = DateTime.now().millisecondsSinceEpoch.toString();
    _chatIds.add(newChatId);
    await prefs.setStringList('chatIds', _chatIds);
    setState(() {}); // Refresh the list
    _navigateToChat(newChatId);
  }

  Future<void> _deleteChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    _chatIds.remove(chatId);
    await prefs.setStringList('chatIds', _chatIds);
    await prefs.remove('chat_$chatId'); // Remove associated messages
    setState(() {}); // Refresh the list
  }


  void _navigateToChat(String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(chatId: chatId), // Pass the chat ID
      ),
    );
  }

  Future<String> _getChatSummary(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    // For simplicity, let's just show the first message as a summary
    // In a real app, you might store and retrieve a dedicated summary
    final messages = prefs.getStringList('chat_$chatId') ?? [];
    if (messages.isNotEmpty) {
      return messages.first;
    }
    return 'New Chat';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Chats'),
        backgroundColor: Color.fromARGB(255, 0, 180, 14),
      ),
      body: _chatIds.isEmpty
          ? const Center(
              child: Text("No chat history available"),
            )
          : ListView.builder(
        itemCount: _chatIds.length,
        itemBuilder: (context, index) {
          final chatId = _chatIds[index];
          return FutureBuilder<String>(
            future: _getChatSummary(chatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                return ListTile(
                  title: Text('Chat ${index + 1}'),
                  subtitle: Text(snapshot.data!),
                  onTap: () => _navigateToChat(chatId),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => _deleteChat(chatId),
                  ),
                );
              }
              return const ListTile(
                title: Text('Loading Chat...'),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        tooltip: 'Start New Chat',
        child: const Icon(Icons.add),
        backgroundColor: Color.fromARGB(255, 0, 180, 14), // Changed color to match the home page
      ),
    );
  }
}