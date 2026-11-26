import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../ranking/ranking_data.dart';
import '../ranking/ranking_widgets.dart';
import '../ranking/ranking_header.dart';
import '../theme/app_theme.dart';

enum _RankingPage {
  basketball(RankingSport.basketball),
  runningFive(RankingSport.running, RunningDistance.five),
  runningTen(RankingSport.running, RunningDistance.ten),
  runningHalf(RankingSport.running, RunningDistance.half),
  runningFull(RankingSport.running, RunningDistance.full),
  soccer(RankingSport.soccer);

  const _RankingPage(this.sport, [this.distance = RunningDistance.five]);
  final RankingSport sport;
  final RunningDistance distance;
}

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().members.profile;
    final initial = profile?.favorites.contains('런닝') == true
        ? _RankingPage.runningFive
        : profile?.sports.length == 1 && profile!.sports.first == '축구'
        ? _RankingPage.soccer
        : _RankingPage.basketball;
    // Recreate controllers and scroll storage when the signed-in account changes.
    return _RankingPager(key: ValueKey(profile?.id), initialPage: initial);
  }
}

class _RankingPager extends StatefulWidget {
  const _RankingPager({super.key, required this.initialPage});
  final _RankingPage initialPage;
  @override
  State<_RankingPager> createState() => _RankingPagerState();
}

class _RankingPagerState extends State<_RankingPager>
    with TickerProviderStateMixin {
  late final _pages = PageController(
    initialPage: widget.initialPage.index,
    keepPage: false,
  );
  final _scrollStorage = PageStorageBucket();
  late _RankingPage _current = widget.initialPage;
  _RankingPage _lastRunning = _RankingPage.runningFive;
  String? _error;
  bool _loading = false;
  bool _selectingDirectly = false;
  late double _lastPagePosition = widget.initialPage.index.toDouble();
  late RunningDistance _visibleDistance = widget.initialPage.distance;
  late final AnimationController _sportSelection,
      _distanceSelection,
      _runningVisibility;
  late final Listenable _headerAnimation;

  @override
  void initState() {
    super.initState();
    _sportSelection = AnimationController.unbounded(
      vsync: this,
      value: _sportPosition(_lastPagePosition),
    );
    _runningVisibility = AnimationController(
      vsync: this,
      value: _runningAmount(_lastPagePosition),
    );
    _distanceSelection = AnimationController.unbounded(
      vsync: this,
      value: widget.initialPage.distance.index.toDouble(),
    );
    _headerAnimation = Listenable.merge([
      _sportSelection,
      _distanceSelection,
      _runningVisibility,
    ]);
    _pages.addListener(_followPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !context.read<AppState>().members.busy) _refresh();
    });
  }

  Future<void> _refresh() async {
    final vm = context.read<AppState>().members;
    if (_loading || vm.busy) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await vm.refreshRankings();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) _error = '랭킹을 불러오지 못했어요. 마지막으로 읽은 목록을 표시합니다. 다시 시도해주세요.';
    });
  }

  @override
  void dispose() {
    _pages.removeListener(_followPage);
    _pages.dispose();
    _sportSelection.dispose();
    _distanceSelection.dispose();
    _runningVisibility.dispose();
    super.dispose();
  }

  void _selectSport(RankingSport sport) => _selectPage(
    sport == RankingSport.running
        ? _lastRunning
        : sport == RankingSport.basketball
        ? _RankingPage.basketball
        : _RankingPage.soccer,
  );

  void _selectDistance(RunningDistance distance) => _selectPage(
    _RankingPage.values.firstWhere(
      (p) => p.sport == RankingSport.running && p.distance == distance,
    ),
  );

  static double _sportPosition(double page) =>
      page.clamp(0.0, 1.0) + (page - 4).clamp(0.0, 1.0);
  static double _runningAmount(double page) =>
      (page < 1
              ? page
              : page > 4
              ? 5 - page
              : 1.0)
          .clamp(0.0, 1.0);

  void _followPage() {
    if (_selectingDirectly || !_pages.hasClients) return;
    final page = (_pages.page ?? _current.index.toDouble()).clamp(0.0, 5.0);
    if ((page - _lastPagePosition).abs() < .000001) return;
    _lastPagePosition = page;
    _visibleDistance = page <= 1
        ? RunningDistance.five
        : page >= 4
        ? RunningDistance.full
        : RunningDistance.values[(page.round() - 1).clamp(0, 3)];
    if (MediaQuery.disableAnimationsOf(context)) return;
    _sportSelection.value = _sportPosition(page);
    _distanceSelection.value = (page - 1).clamp(0.0, 3.0);
    _runningVisibility.value = _runningAmount(page);
  }

  void _showSelection(_RankingPage page, {required bool animate}) {
    final duration = animate && !MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 180)
        : Duration.zero;
    final sport = _sportPosition(page.index.toDouble());
    final running = page.sport == RankingSport.running ? 1.0 : 0.0;
    final distance = _visibleDistance.index.toDouble();
    if (duration == Duration.zero) {
      _sportSelection.value = sport;
      _distanceSelection.value = distance;
      _runningVisibility.value = running;
    } else {
      _sportSelection.animateTo(
        sport,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
      _distanceSelection.animateTo(
        distance,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
      _runningVisibility.animateTo(
        running,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectPage(_RankingPage page) {
    if (page.sport == RankingSport.running) _visibleDistance = page.distance;
    _selectingDirectly = true;
    try {
      _pages.jumpToPage(page.index);
      _lastPagePosition = page.index.toDouble();
    } finally {
      _selectingDirectly = false;
    }
    _showSelection(page, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppState>().members.busy;
    return PageStorage(
      bucket: _scrollStorage,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ...ScrollConfiguration.of(context).dragDevices,
            PointerDeviceKind.mouse,
          },
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  key: const Key('ranking-header-viewport'),
                  constraints: BoxConstraints(
                    maxWidth: 850,
                    maxHeight: constraints.maxHeight * .45,
                  ),
                  child: SingleChildScrollView(
                    key: const PageStorageKey('ranking-header-scroll'),
                    primary: false,
                    child: AnimatedBuilder(
                      animation: _headerAnimation,
                      builder: (context, _) => RankingHeader(
                        sport: _current.sport,
                        distance: _visibleDistance,
                        sportPosition: _sportSelection.value,
                        distancePosition: _distanceSelection.value,
                        runningVisibility: _runningVisibility.value,
                        onRefresh: _loading || busy ? null : _refresh,
                        onSportSelected: _selectSport,
                        onDistanceSelected: _selectDistance,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const Key('ranking-pages'),
                  controller: _pages,
                  itemCount: _RankingPage.values.length,
                  onPageChanged: (index) {
                    setState(() {
                      _current = _RankingPage.values[index];
                      if (_current.sport == RankingSport.running) {
                        _lastRunning = _current;
                      }
                    });
                    if (MediaQuery.disableAnimationsOf(context)) {
                      _showSelection(_current, animate: false);
                    }
                  },
                  itemBuilder: (context, index) {
                    final page = _RankingPage.values[index];
                    return ExcludeFocus(
                      excluding: page != _current,
                      child: ExcludeSemantics(
                        excluding: page != _current,
                        child: _RankingPanel(
                          key: ValueKey(page),
                          page: page,
                          loading: _loading,
                          error: _error,
                          onRefresh: _refresh,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({
    super.key,
    required this.page,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });
  final _RankingPage page;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  RankingSport get _sport => page.sport;
  RunningDistance get _distance => page.distance;
  bool get _loading => loading;
  String? get _error => error;
  Future<void> _refresh() => onRefresh();

  void _showRules(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${_sport.label} 집계 기준'),
      content: SingleChildScrollView(child: Text(rankingRules(_sport))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.members.profile;
    final source = app.members.operations.sportRankings;
    final rows = rankSportEntries(source, _sport, distance: _distance);
    final mine = rows.where((r) => r.entry.belongsTo(profile?.id)).toList();
    final pending = source
        .where(
          (e) =>
              e.sport == _sport &&
              e.belongsTo(profile?.id) &&
              e.validate() == null &&
              (_sport == RankingSport.basketball
                  ? e.games < 5
                  : _sport == RankingSport.soccer
                  ? e.games == 0
                  : false),
        )
        .toList();
    final scheme = Theme.of(context).colorScheme;
    final running = _sport == RankingSport.running;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: PageStorageKey('sport-rankings-${page.name}'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(semanticsLabel: '랭킹을 불러오는 중'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error!,
                          key: const Key('ranking-load-error'),
                          style: TextStyle(color: scheme.error),
                        ),
                        TextButton(
                          onPressed: _loading || app.members.busy
                              ? null
                              : _refresh,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          running
                              ? '${_distance.label} 개인 랭킹'
                              : '${_sport.label} 팀 랭킹',
                          key: const Key('ranking-title'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          rows.isEmpty
                              ? '운영자 입력 성적'
                              : rows.every((r) => r.entry.isDemo)
                              ? '예시 데이터'
                              : rows.any((r) => r.entry.isDemo)
                              ? '예시 · 운영자 입력'
                              : '운영자 입력 성적',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          switch (_sport) {
                            RankingSport.basketball => '승률 기준 · 최소 5경기',
                            RankingSport.soccer => '승점 기준 · 승 3 / 무 1 / 패 0',
                            RankingSport.running => '전체 기간 · 개인 최고 기록',
                          },
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('ranking-rules'),
                          onPressed: () => _showRules(context),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('집계 기준'),
                        ),
                      ],
                    ),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          '아직 등록된 랭킹이 없어요.\n집계 기준을 충족한 기록이 등록되면 표시돼요.',
                          key: Key('ranking-empty'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (rows.isNotEmpty)
                      RankingPodium(
                        rows: rows.take(3).toList(),
                        accountId: profile?.id,
                      ),
                  ],
                ),
              ),
              if (rows.length > 3) ...[
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '나머지 순위',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        running
                            ? '러너 · 달성일 · 최고 기록'
                            : _sport == RankingSport.basketball
                            ? '팀 · 승·패 · 승률'
                            : '팀 · 승·무·패 · 승점',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final row in rows.skip(3))
                        SportRankingRow(
                          row: row,
                          mine: row.entry.belongsTo(profile?.id),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SectionCard(
                color: scheme.primaryContainer,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: scheme.onPrimaryContainer),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        running ? '내 순위' : '내 팀 순위',
                        key: const Key('ranking-mine-title'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (mine.isEmpty && pending.isEmpty)
                        Text(
                          running
                              ? '이 거리에서 내 계정에 연결된 완주 기록이 없어요.'
                              : '내 계정에 연결된 팀 성적이 없어요.',
                        ),
                      for (final row in mine)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${row.rankLabel} · ${row.entry.name}\n${row.entry.valueLabel} · ${row.entry.detailLabel}${row.entry.isDemo ? '\n예시 데이터' : ''}',
                            key: Key('ranking-mine-${row.entry.id}'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      for (final entry in pending)
                        Text(
                          '${entry.name} · 집계 대기\n${entry.detailLabel}${_sport == RankingSport.basketball ? '\n최소 5경기부터 순위에 포함돼요.' : '\n첫 경기 성적이 등록되면 표시돼요.'}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '예시 또는 운영자가 입력한 성적을 집계합니다. 이 기기의 저장 데이터를 사용하며, 경기 결과·GPS 기록을 자동 수집하지 않습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                '홈의 주간 TOP 3는 운동 횟수 기준의 별도 활동 랭킹입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
