import 'package:flutter/material.dart';

/// 채팅 메시지 한 개
class ChatMessage {
  final String text;
  final bool fromUser; // true: 사용자, false: AI

  const ChatMessage(this.text, {required this.fromUser});
}

/// PDF 6페이지: AI 운동 도우미 (하단 탭 3번)
/// 여러 용도로 활용 가능한 AI 챗봇.
/// ① 사용자의 질문 입력  ex) 농구 5대5 경기에서 엘리베이터 전술이 뭐야?
///
/// 지금은 화면 구성 단계라 AI 답변은 가짜(더미)로 보여준다.
/// TODO(팀): _askAi()를 실제 LLM API 호출(http 패키지 + async/await)로 교체.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [
    const ChatMessage('안녕하세요! 운동 관련해서 무엇이든 물어보세요.\n'
        '예) 농구 5대5 경기에서 엘리베이터 전술이 뭐야?', fromUser: false),
  ];
  bool _waiting = false; // AI 답변 기다리는 중인지

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _waiting) return;

    setState(() {
      _messages.add(ChatMessage(text, fromUser: true));
      _waiting = true;
    });
    _controller.clear();
    _scrollToBottom();

    final reply = await _askAi(text); // [6강] 비동기: 답이 올 때까지 기다림 (화면은 안 멈춤)
    if (!mounted) return;

    setState(() {
      _messages.add(ChatMessage(reply, fromUser: false));
      _waiting = false;
    });
    _scrollToBottom();
  }

  /// 가짜 AI. 1초 기다렸다가 답을 돌려준다.
  Future<String> _askAi(String question) async {
    await Future.delayed(const Duration(seconds: 1));
    return '(예시 답변) "$question"에 대한 답변은 LLM 연결 후 제공될 예정이에요.';
  }

  void _scrollToBottom() {
    // 새 메시지가 그려진 "다음 프레임"에 맨 아래로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 말풍선 목록
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length + (_waiting ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                // 답변 기다리는 중 표시
                return const _Bubble(
                  message: ChatMessage('입력 중...', fromUser: false),
                );
              }
              return _Bubble(message: _messages[i]);
            },
          ),
        ),
        const Divider(height: 1),
        // ① 질문 입력창
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '운동에 대해 질문해보세요',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _waiting ? null : _send, // 기다리는 중엔 버튼 비활성화
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 말풍선 하나: AI는 왼쪽(아이콘 + 회색), 사용자는 오른쪽(파란색)
class _Bubble extends StatelessWidget {
  final ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final scheme = Theme.of(context).colorScheme;

    final bubble = Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? scheme.primaryContainer : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.text),
      ),
    );

    final avatar = CircleAvatar(
      radius: 16,
      child: isUser
          ? const Icon(Icons.person, size: 18)
          : const Text('AI', style: TextStyle(fontSize: 12)),
    );

    return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isUser
          ? [const SizedBox(width: 48), bubble, const SizedBox(width: 6), avatar]
          : [avatar, const SizedBox(width: 6), bubble, const SizedBox(width: 48)],
    );
  }
}
