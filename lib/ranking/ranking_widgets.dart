import 'package:flutter/material.dart';
import 'ranking_data.dart';

IconData rankingSportIcon(RankingSport sport) => switch (sport) {
  RankingSport.basketball => Icons.sports_basketball_outlined,
  RankingSport.soccer => Icons.sports_soccer,
  RankingSport.running => Icons.directions_run_rounded,
};

class RankingPodium extends StatelessWidget {
  const RankingPodium({super.key, required this.rows, this.accountId});
  final List<RankedSportEntry> rows;
  final String? accountId;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 290 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      final ordered = compact || rows.length < 3
          ? rows
          : [rows[1], rows[0], rows[2]];
      if (compact) {
        return Column(
          children: [
            for (final row in ordered)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PodiumCard(
                  row: row,
                  mine: row.entry.belongsTo(accountId),
                ),
              ),
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in ordered)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _PodiumCard(
                    row: row,
                    mine: row.entry.belongsTo(accountId),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.row, required this.mine});
  final RankedSportEntry row;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('ranking-podium-${row.entry.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: row.rank == 1
            ? scheme.primaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: mine ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: row.rank == 1
                ? const Color(0xFFBD8A18)
                : scheme.onSurfaceVariant,
            size: 24,
          ),
          Text(
            row.rankLabel,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            backgroundColor: scheme.surface,
            foregroundColor: scheme.primary,
            child: Icon(rankingSportIcon(row.entry.sport)),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: row.entry.name,
            child: Text(
              row.entry.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.entry.valueLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            row.entry.detailLabel.replaceFirst(' · ', '\n'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (mine) ...[
            const SizedBox(height: 4),
            Text(
              row.entry.sport == RankingSport.running ? '내 기록' : '내 팀',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          Text(
            row.entry.isDemo ? '예시' : '운영자 입력',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class SportRankingRow extends StatelessWidget {
  const SportRankingRow({super.key, required this.row, required this.mine});
  final RankedSportEntry row;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('ranking-row-${row.entry.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row.rankLabel} · ${row.entry.name}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${row.entry.detailLabel} · ${row.entry.isDemo ? '예시' : '운영자 입력'}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          );
          final value = Text(
            row.entry.valueLabel,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          );
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 21) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [content, const SizedBox(height: 6), value],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              value,
            ],
          );
        },
      ),
    );
  }
}
