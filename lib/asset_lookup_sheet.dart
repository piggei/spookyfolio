import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'asset_lookup_models.dart';
import 'portfolio_client.dart';

class AssetLookupSheet extends StatefulWidget {
  const AssetLookupSheet({
    super.key,
    required this.serverUrl,
    required this.jwt,
    this.client,
  });

  final String serverUrl;
  final String jwt;
  final PortfolioClient? client;

  @override
  State<AssetLookupSheet> createState() => _AssetLookupSheetState();
}

class _AssetLookupSheetState extends State<AssetLookupSheet> {
  final _controller = TextEditingController();

  Timer? _debounce;
  int _generation = 0;
  bool _loading = false;
  String? _error;
  List<AssetLookupItem> _items = [];

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final generation = ++_generation;

    if (query.trim().isEmpty) {
      setState(() {
        _items = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _items = [];
      _error = null;
      _loading = true;
    });

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(query, generation),
    );
  }

  Future<void> _search(String query, int generation) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await (widget.client ?? PortfolioClient()).lookupAssets(
        serverUrl: widget.serverUrl,
        jwt: widget.jwt,
        query: query,
      );

      if (!mounted || generation != _generation) return;

      setState(() {
        _items = result.items;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;

      setState(() {
        _items = [];
        _error = error is PortfolioApiException
            ? error.message
            : 'Unable to search assets.';
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter Activity by asset',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                onSubmitted: (query) {
                  _debounce?.cancel();
                  final generation = ++_generation;
                  _search(query, generation);
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by name or symbol',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                    ? Center(
                        child: Text(
                          _controller.text.isEmpty
                              ? 'Search for an asset.'
                              : 'No matching assets.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            enabled: item.canFilter,
                            title: Text(item.name ?? item.symbol),
                            subtitle: Text('${item.symbol} · ${item.currency}'),
                            trailing: item.canFilter
                                ? Text(item.dataSource!)
                                : const Tooltip(
                                    message: 'Asset source unavailable',
                                    child: Icon(Icons.info_outline),
                                  ),
                            onTap: item.canFilter
                                ? () => Navigator.of(context).pop(item)
                                : null,
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
