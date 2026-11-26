import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ranking_data.dart';

/// Shared controls stay outside the horizontally scrolling ranking pages.
class RankingHeader extends StatelessWidget {
  const RankingHeader({
    super.key,
    required this.sport,
    required this.distance,
    required this.sportPosition,
    required this.distancePosition,
    required this.runningVisibility,
    required this.onSportSelected,
    required this.onDistanceSelected,
    this.onRefresh,
  });

  final RankingSport sport;
  final RunningDistance distance;
  final double sportPosition, distancePosition, runningVisibility;
  final ValueChanged<RankingSport> onSportSelected;
  final ValueChanged<RunningDistance> onDistanceSelected;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final visibility = runningVisibility.clamp(0.0, 1.0);
    return Padding(
      key: const Key('ranking-fixed-header'),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            key: const Key('ranking-header-core'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '함께 도전하는 랭킹',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('ranking-refresh'),
                    tooltip: '랭킹 새로고침',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SlidingRankingTabs<RankingSport>(
                values: RankingSport.values,
                selected: sport,
                position: sportPosition,
                label: (value) => value.label,
                buttonKey: (value) => Key('ranking-sport-${value.name}'),
                indicatorKey: const Key('ranking-sport-indicator'),
                onSelected: onSportSelected,
              ),
            ],
          ),
          if (visibility > 0)
            ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: visibility,
                child: Opacity(
                  opacity: visibility,
                  child: IgnorePointer(
                    ignoring: sport != RankingSport.running,
                    child: ExcludeFocus(
                      excluding: sport != RankingSport.running,
                      child: ExcludeSemantics(
                        excluding: sport != RankingSport.running,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _SlidingRankingTabs<RunningDistance>(
                            key: const Key('ranking-distance-controls'),
                            values: RunningDistance.values,
                            selected: distance,
                            position: distancePosition,
                            label: (value) => value.label,
                            buttonKey: (value) =>
                                Key('ranking-distance-${value.name}'),
                            indicatorKey: const Key(
                              'ranking-distance-indicator',
                            ),
                            onSelected: onDistanceSelected,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Equal-width targets keep their positions while the shared indicator slides.
/// Large labels can scroll horizontally instead of clipping or shrinking text.
class _SlidingRankingTabs<T> extends StatelessWidget {
  const _SlidingRankingTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.position,
    required this.label,
    required this.buttonKey,
    required this.indicatorKey,
    required this.onSelected,
  });
  final List<T> values;
  final T selected;
  final double position;
  final String Function(T) label;
  final Key Function(T) buttonKey;
  final Key indicatorKey;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge!;
    return LayoutBuilder(
      builder: (context, constraints) {
        var minimumWidth = 64.0;
        for (final value in values) {
          final painter = TextPainter(
            text: TextSpan(text: label(value), style: labelStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          minimumWidth = math.max(minimumWidth, painter.width + 12);
          painter.dispose();
        }
        final totalWidth = math.max(
          constraints.maxWidth,
          minimumWidth * values.length,
        );
        final width = totalWidth / values.length;
        final progress = position.clamp(0.0, values.length - 1.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final _ in values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: width * progress + 2,
                  top: 0,
                  bottom: 0,
                  width: width - 4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: indicatorKey,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var index = 0; index < values.length; index++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: TextButton(
                            key: buttonKey(values[index]),
                            style: TextButton.styleFrom(
                              textStyle: labelStyle,
                              backgroundColor: Colors.transparent,
                              foregroundColor: Color.lerp(
                                scheme.onSurfaceVariant,
                                scheme.onPrimary,
                                (1 - (progress - index).abs()).clamp(0.0, 1.0),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                            ).copyWith(animationDuration: Duration.zero),
                            onPressed: () => onSelected(values[index]),
                            child: Semantics(
                              selected: selected == values[index],
                              child: Text(label(values[index])),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
