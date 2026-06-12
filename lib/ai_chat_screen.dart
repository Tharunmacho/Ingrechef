import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChefChatService();
  final _imagePicker = ImagePicker();

  List<ChatMessage> _messages = [
    ChatMessage(
      content:
      "Hey there! 👋 I'm your AI sous-chef. Tell me what's in your fridge and I'll suggest delicious meals with zero waste!",
      isBot: true,
      timestamp: DateTime.now(),
    ),
    ChatMessage(
      content:
      "You can:\n• List your ingredients for meal ideas 🥦\n• Ask for recipes and cooking tips 🍳\n• Request ingredient substitutions 🔄\n• Send a fridge photo for analysis 📸",
      isBot: true,
      timestamp: DateTime.now(),
    ),
  ];

  bool _isTyping = false;
  File? _selectedImage;

  late AnimationController _typingController;

  final List<String> _quickReplies = [
    '🥦 What can I cook with spinach?',
    '⏱️ Quick 15-min meals',
    '🔄 Substitute for eggs?',
    '🥗 Vegetarian ideas',
  ];

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _msgController.text).trim();
    final image = _selectedImage;

    if (text.isEmpty && image == null) return;

    final userMsg = ChatMessage(
      content: text,
      isBot: false,
      timestamp: DateTime.now(),
      imageFile: image,
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
      _selectedImage = null;
    });

    _msgController.clear();
    _scrollToBottom();

    try {
      final response = await _chatService.sendMessage(
        message: text.isNotEmpty ? text : null,
        imageFile: image,
      );

      setState(() {
        _isTyping = false;

        _messages.add(
          ChatMessage(
            content: response,
            isBot: true,
            timestamp: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _isTyping = false;

        _messages.add(
          ChatMessage(
            content:
            "Sorry, I'm having trouble right now. Please try again in a moment! 😅",
            isBot: true,
            timestamp: DateTime.now(),
          ),
        );
      });
    }

    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: const Color(0xFFE84C4C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A1E),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE8A84C),
                    Color(0xFFD4873A),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  '🤖',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Sous-Chef',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: Color(0xFF4AE84A),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Color(0xFF8BBB8B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.clear_all_rounded,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _messages = [
                  ChatMessage(
                    content:
                    "Chat cleared! How can I help you cook today? 🍳",
                    isBot: true,
                    timestamp: DateTime.now(),
                  ),
                ];
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isTyping && i == _messages.length) {
                  return _buildTypingIndicator();
                }

                return _buildBubble(_messages[i]);
              },
            ),
          ),

          if (_messages.length <= 3)
            SizedBox(
              height: 46,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickReplies.length,
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => _sendMessage(_quickReplies[i]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF8BBB8B),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        _quickReplies[i],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3D6B3D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (_selectedImage != null) _buildImagePreview(),

                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            builder: (_) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Share Image',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _AttachOption(
                                          icon: Icons.camera_alt,
                                          label: 'Camera',
                                          color: const Color(0xFF2D4A2D),
                                          onTap: () => _pickImage(
                                            ImageSource.camera,
                                          ),
                                        ),
                                        _AttachOption(
                                          icon: Icons.photo_library,
                                          label: 'Gallery',
                                          color: const Color(0xFF5A7BA8),
                                          onTap: () => _pickImage(
                                            ImageSource.gallery,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF5EE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.attach_file_rounded,
                            color: Color(0xFF3D6B3D),
                            size: 22,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          maxLines: 4,
                          minLines: 1,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E3A1E),
                          ),
                          decoration: InputDecoration(
                            hintText: _selectedImage != null
                                ? 'Describe what you want to know...'
                                : 'Ask your sous-chef...',
                            hintStyle: const TextStyle(
                              color: Color(0xFFBBB6A8),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF0EDE4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: Color(0xFF5A8A5A),
                                width: 1.5,
                              ),
                            ),
                            contentPadding:
                            const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),

                      const SizedBox(width: 10),

                      GestureDetector(
                        onTap: () => _sendMessage(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4A8A4A),
                                Color(0xFF2D5A2D),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF2D4A2D,
                                ).withOpacity(0.35),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isBot = msg.isBot;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE8A84C),
                    Color(0xFFD4873A),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  '🤖',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
              isBot
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isBot
                        ? Colors.white
                        : const Color(0xFF2D4A2D),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isBot ? 4 : 18),
                      bottomRight: Radius.circular(isBot ? 18 : 4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      if (msg.imageFile != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            msg.imageFile!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (msg.content.isNotEmpty)
                          const SizedBox(height: 8),
                      ],

                      if (msg.content.isNotEmpty)
                        Text(
                          msg.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: isBot
                                ? const Color(0xFF1E3A1E)
                                : Colors.white,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _fmtTime(msg.timestamp),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9A9A9A),
                  ),
                ),
              ],
            ),
          ),

          if (!isBot) ...[
            const SizedBox(width: 8),

            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF3D6B3D),
                    Color(0xFF2D4A2D),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  '👤',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE8A84C),
                  Color(0xFFD4873A),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                '🤖',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                    (i) => AnimatedBuilder(
                  animation: _typingController,
                  builder: (_, __) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                          const Color(0xFFCCC9BC),
                          const Color(0xFF3D6B3D),
                          ((_typingController.value + i * 0.3) % 1.0),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDE4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'Image selected – send to analyse 🔍',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF3A4A3A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.grey,
              size: 18,
            ),
            onPressed: () {
              setState(() {
                _selectedImage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}