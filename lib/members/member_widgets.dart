import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_routes.dart';
import 'member_controller.dart';

class MemberPage extends StatelessWidget {
  const MemberPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
    this.onBack,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final showBack = uri.path != AppRoutes.login;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        automaticallyImplyLeading: false,
        leading: showBack
            ? BackButton(
                onPressed:
                    onBack ??
                    () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        final publicPage = [
                          AppRoutes.signup,
                          AppRoutes.demo,
                          AppRoutes.reset,
                        ].contains(uri.path);
                        context.go(
                          publicPage
                              ? Uri(
                                  path: AppRoutes.login,
                                  queryParameters: AppRoutes.returnQuery(
                                    uri.queryParameters['from'],
                                  ),
                                ).toString()
                              : AppRoutes.me,
                        );
                      }
                    },
              )
            : null,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(minimum: const EdgeInsets.all(16), child: bottom!),
    );
  }
}

class MemberError extends StatelessWidget {
  const MemberError(this.controller, {super.key});
  final MemberController controller;
  @override
  Widget build(BuildContext context) => controller.error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              controller.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        );
}

class MemberHeading extends StatelessWidget {
  const MemberHeading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

InputDecoration memberInput(
  String label, {
  String? hint,
  String? error,
  Widget? suffix,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  errorText: error,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  suffixIcon: suffix,
);

class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final v in options)
              FilterChip(
                key: ValueKey('$label:$v'),
                label: Text(v),
                selected: selected.contains(v),
                onSelected: (_) => onSelected(v),
              ),
          ],
        ),
      ],
    ),
  );
}

Future<bool> confirmDiscard(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('변경사항을 버릴까요?'),
    content: const Text('저장하지 않은 입력은 반영되지 않아요.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('계속 수정'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('변경 버리기'),
      ),
    ],
  ),
).then((v) => v ?? false);
