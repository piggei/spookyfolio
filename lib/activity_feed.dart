import 'package:material_ui/material_ui.dart';

import 'activity_models.dart';
import 'portfolio_client.dart';

/// Lazy, paginated activity list. Remains mounted inside MobileShell's IndexedStack.
class ActivityFeed extends StatefulWidget {
  const ActivityFeed({
    super.key,
    required this.serverUrl,
    required this.jwt,
    required this.active,
    this.accountId,
    this.client,
  });

  final String serverUrl;
  final String jwt;
  final bool active;
  final String? accountId;
  final PortfolioClient? client;

  @override
  State<ActivityFeed> createState() => ActivityFeedState();
}

class ActivityFeedState extends State<ActivityFeed> {
  static const _pageSize = 40;
  final _items = <PortfolioActivity>[];
  final _ids = <String>{};
  int _count = 0;
  int _offset = 0;
  bool _started = false;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _loadAfterFrame();
  }

  @override
  void didUpdateWidget(covariant ActivityFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jwt != oldWidget.jwt ||
        widget.serverUrl != oldWidget.serverUrl ||
        widget.accountId != oldWidget.accountId) {
      _reset();
    }
    if (widget.active && !_started) _loadAfterFrame();
  }

  void _loadAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && !_started) _load();
    });
  }

  void _reset() {
    _generation++;
    _items.clear();
    _ids.clear();
    _count = 0;
    _offset = 0;
    _started = false;
    _loading = false;
    _error = null;
  }

  Future<void> refresh() => _load(refresh: true);

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    if (refresh) _reset();
    final generation = _generation;
    final skip = _offset;
    setState(() {
      _started = true;
      _loading = true;
      _error = null;
    });
    try {
      final api = widget.client ?? PortfolioClient();
      final accountId = widget.accountId;
      final result = accountId == null
          ? await api.getActivities(
              serverUrl: widget.serverUrl,
              jwt: widget.jwt,
              skip: skip,
              take: _pageSize,
            )
          : await api.getActivitiesForAccount(
              serverUrl: widget.serverUrl,
              jwt: widget.jwt,
              accountId: accountId,
              skip: skip,
              take: _pageSize,
            );
      if (!mounted || generation != _generation) return;
      setState(() {
        _count = result.count;
        _offset += result.activities.length;
        for (final item in result.activities) {
          if (_ids.add(item.id)) _items.add(item);
        }
        _items.sort((a, b) => b.date.compareTo(a.date));
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _error = error is PortfolioApiException
            ? error.message
            : 'Unable to load activities.',
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final more = _offset < _count;
    return ListView(
      key: const ValueKey('activity-page'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Activity ($_count)',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        if (_items.isEmpty && !_loading && _error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No transactions yet.')),
          ),
        for (final activity in _items) ActivityCard(activity: activity),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: _loading ? null : _load,
            child: const Text('Retry'),
          ),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (more && !_loading && _error == null)
          OutlinedButton(
            onPressed: _load,
            child: Text('Load more (${_items.length} of $_count)'),
          ),
      ],
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity});
  final PortfolioActivity activity;

  static String _number(double? value, {int digits = 2}) =>
      value == null ? '—' : value.toStringAsFixed(digits);

  static String _amount(double? value, String? currency) => value == null
      ? 'Not available'
      : '${_number(value)}${currency == null ? '' : ' $currency'}';

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final description = a.name ?? a.symbol ?? a.type;
    final date =
        '${a.date.day.toString().padLeft(2, '0')}/'
        '${a.date.month.toString().padLeft(2, '0')}/${a.date.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    description,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _amount(a.value, a.currency),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                Text(
                  a.type,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(date),
                if (a.symbol != null) Text(a.symbol!),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Quantity: ${_number(a.quantity, digits: 4)}'),
                Text('Unit price: ${_amount(a.unitPrice, a.currency)}'),
                Text('Fee: ${_amount(a.fee, a.currency)}'),
              ],
            ),
            if (a.accountName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Account: ${a.accountName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
