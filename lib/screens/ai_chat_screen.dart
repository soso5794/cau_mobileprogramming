import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ai/ai_gateway.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.gateway});
  final AiGateway gateway;
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<AiTurn> _messages = [
    const AiTurn('안녕하세요! 운동 전술이나 훈련 방법을 물어보세요.', fromUser: false),
  ];
  bool _waiting = false;
  String? _error;
  int _generation = 0;
  static const suggestions = [
    '농구 엘리베이터 전술이 뭐야?',
    '초보 러닝 주간 계획 추천',
    '비 오는 날 실내 운동',
  ];
  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> send({bool retry = false}) async {
    if (_waiting) return;
    final text = retry ? _messages.last.text : _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 2000) {
      setState(() => _error = '질문은 2,000자 이내로 입력해주세요.');
      return;
    }
    final owner = context.read<AppState>().loginId;
    final generation = ++_generation;
    setState(() {
      if (!retry) {
        if (_messages.length > 1 && _messages.last.fromUser) {
          _messages.removeLast();
        }
        _messages.add(AiTurn(text, fromUser: true));
      }
      _error = null;
      _waiting = true;
    });
    _controller.clear();
    bottom();
    try {
      final history = _messages.skip(1).toList();
      final reply = await widget.gateway.answer(
        history.length > 19 ? history.sublist(history.length - 19) : history,
      );
      if (!mounted ||
          generation != _generation ||
          context.read<AppState>().loginId != owner) {
        return;
      }
      setState(() => _messages.add(AiTurn(reply, fromUser: false)));
    } on AiFailure catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '답변을 받지 못했어요. 다시 시도해주세요.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _waiting = false);
        bottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '질문과 최근 대화가 OpenAI로 전송돼요. 프로필·캘린더는 자동 전송하지 않아요.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: '새 대화',
              onPressed: _waiting
                  ? null
                  : () => setState(() {
                      _messages.removeRange(1, _messages.length);
                      _error = null;
                      _generation++;
                    }),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          itemCount:
              _messages.length + (_waiting ? 1 : 0) + (_error != null ? 1 : 0),
          itemBuilder: (c, i) {
            if (i < _messages.length) return _Bubble(message: _messages[i]);
            if (_waiting) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text('답변을 작성하고 있어요…'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (_messages.last.fromUser)
                  TextButton.icon(
                    key: const Key('ai-retry'),
                    onPressed: () => send(retry: true),
                    icon: const Icon(Icons.replay),
                    label: const Text('다시 시도'),
                  ),
              ],
            );
          },
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final q in suggestions)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(q),
                  onPressed: _waiting
                      ? null
                      : () {
                          _controller.text = q;
                          send();
                        },
                ),
              ),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ai-input'),
                  controller: _controller,
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  decoration: appInputDecoration(
                    context,
                    hint: '운동에 대해 질문해보세요',
                    icon: Icons.chat_bubble_outline_rounded,
                  ).copyWith(counterText: ''),
                  onSubmitted: (_) => send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('ai-send'),
                tooltip: '질문 보내기',
                onPressed: _waiting ? null : () => send(),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Bubble extends StatelessWidget {
  final AiTurn message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const big = Radius.circular(18);
    const small = Radius.circular(4);

    final bubble = Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [AppTheme.gradientStart, AppTheme.gradientEnd],
                )
              : null,
          color: isUser
              ? null
              : (isDark ? scheme.surfaceContainerHigh : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: isUser ? big : small,
            topRight: isUser ? small : big,
            bottomLeft: big,
            bottomRight: big,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Text(
          message.text,
          style: TextStyle(color: isUser ? Colors.white : null, height: 1.4),
        ),
      ),
    );

    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: isUser ? scheme.secondaryContainer : scheme.primary,
      foregroundColor: isUser ? scheme.onSecondaryContainer : scheme.onPrimary,
      child: isUser
          ? const Icon(Icons.person_rounded, size: 20)
          : const Icon(Icons.smart_toy_rounded, size: 20),
    );

    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isUser
          ? [
              const SizedBox(width: 48),
              bubble,
              const SizedBox(width: 8),
              avatar,
            ]
          : [
              avatar,
              const SizedBox(width: 8),
              bubble,
              const SizedBox(width: 48),
            ],
    );
  }
}
