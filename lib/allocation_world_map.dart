import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'portfolio_allocations.dart';
import 'allocation_chart.dart';

class CountryOutline {
  CountryOutline(this.id, this.name, this.path);
  final String id;
  final String name;

  /// Equirectangular world coordinates in a 360 by 180 viewport.
  final Path path;
}

class AllocationMapGeometry {
  AllocationMapGeometry(this.countries);
  final List<CountryOutline> countries;
  factory AllocationMapGeometry.fromJson(String source) {
    final rows = jsonDecode(source) as List<dynamic>;
    return AllocationMapGeometry(
      List.unmodifiable(
        rows.map((dynamic row) {
          final path = Path()..fillType = PathFillType.evenOdd;
          for (final polygon in row['polygons'] as List<dynamic>) {
            for (final ring in polygon as List<dynamic>) {
              path.addPolygon([
                for (final point in ring as List<dynamic>)
                  Offset(
                    (point[0] as num).toDouble() + 180,
                    90 - (point[1] as num).toDouble(),
                  ),
              ], true);
            }
          }
          return CountryOutline(
            row['id'] as String,
            row['name'] as String,
            path,
          );
        }),
      ),
    );
  }
}

/// Local country polygons: no map services, SDK, credentials or live requests.
class AllocationWorldMap extends StatefulWidget {
  const AllocationWorldMap({
    super.key,
    required this.data,
    required this.currency,
  });
  final AllocationBreakdown data;
  final String? currency;
  @override
  State<AllocationWorldMap> createState() => _AllocationWorldMapState();
}

class _AllocationWorldMapState extends State<AllocationWorldMap> {
  AssetBundle? _bundle;
  Future<AllocationMapGeometry>? _geometry;
  String? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (!identical(bundle, _bundle)) {
      _bundle = bundle;
      _geometry = bundle
          .loadString('assets/maps/world_110m.json')
          .then(AllocationMapGeometry.fromJson);
    }
  }

  @override
  void didUpdateWidget(covariant AllocationWorldMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.data, oldWidget.data)) _selected = null;
  }

  AllocationBucket? _bucket(String? id) {
    for (final bucket in widget.data.buckets) {
      if (bucket.id == id) return bucket;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AllocationMapGeometry>(
    future: _geometry,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text('The offline geographic asset could not be loaded.'),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final geometry = snapshot.requireData;
      final scheme = Theme.of(context).colorScheme;
      final selected = _bucket(_selected);
      String? selectedName;
      for (final country in geometry.countries) {
        if (country.id == _selected) selectedName = country.name;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            image: true,
            label: 'Offline world map of reported country exposure. Use the country selector to inspect values.',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: scheme.surfaceContainerLow,
                child: AspectRatio(
                  aspectRatio: 2,
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      key: const ValueKey('allocation-world-map'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final point = Offset(
                          details.localPosition.dx * 360 / constraints.maxWidth,
                          details.localPosition.dy *
                              180 /
                              constraints.maxHeight,
                        );
                        for (final country in geometry.countries.reversed) {
                          if (country.path.contains(point)) {
                            setState(() => _selected = country.id);
                            break;
                          }
                        }
                      },
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: AllocationMapPainter(
                          geometry: geometry,
                          data: widget.data,
                          selected: _selected,
                          scheme: scheme,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: scheme.primary.withValues(alpha: .25),
              ),
              const Text('Lower exposure'),
              Icon(Icons.arrow_forward, size: 14),
              Icon(Icons.circle, size: 10, color: scheme.primary),
              const Text('Higher exposure'),
              if (widget.data.buckets.any(
                (bucket) => bucket.value != null && bucket.value! < 0,
              )) ...[
                Icon(Icons.circle, size: 10, color: scheme.error),
                const Text('Negative exposure'),
              ],
            ],
          ),
          if (widget.data.buckets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No reported country exposure.'),
            ),
          if (widget.data.buckets.isNotEmpty) ...[
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Inspect a country',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const ValueKey('allocation-country-selector'),
                  isExpanded: true,
                  itemHeight: null,
                  hint: const Text('Choose a country'),
                  value: selected?.id,
                  selectedItemBuilder: (context) => [
                    for (final bucket in widget.data.buckets)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(bucket.id),
                      ),
                  ],
                  items: [
                    for (final bucket in widget.data.buckets)
                      DropdownMenuItem(
                        value: bucket.id,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${bucket.id} · ${allocationLabel(bucket)}',
                          ),
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _selected = id),
                ),
              ),
            ),
          ],
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                key: const ValueKey('allocation-map-selection'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selected!} · ${selected == null ? selectedName ?? _selected! : allocationLabel(selected)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    allocationValue(
                      selected?.value,
                      widget.data.unit,
                      widget.currency,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class AllocationMapPainter extends CustomPainter {
  const AllocationMapPainter({
    required this.geometry,
    required this.data,
    required this.selected,
    required this.scheme,
  });
  final AllocationMapGeometry geometry;
  final AllocationBreakdown data;
  final String? selected;
  final ColorScheme scheme;
  @override
  void paint(Canvas canvas, Size size) {
    final buckets = {for (final bucket in data.buckets) bucket.id: bucket};
    final maximum = data.buckets.fold<double>(
      0,
      (value, bucket) => math.max(value, bucket.value ?? 0),
    );
    canvas.save();
    canvas.scale(size.width / 360, size.height / 180);
    for (final country in geometry.countries) {
      final value = buckets[country.id]?.value;
      final color = value == null
          ? scheme.surfaceContainerHighest
          : value < 0
          ? scheme.error
          : scheme.primary.withValues(
              alpha:
                  .15 + .75 * (maximum > 0 ? value / maximum : 0).clamp(0, 1),
            );
      canvas.drawPath(country.path, Paint()..color = color);
      canvas.drawPath(
        country.path,
        Paint()
          ..color = country.id == selected
              ? scheme.onSurface
              : scheme.outlineVariant
          ..style = PaintingStyle.stroke
          ..strokeWidth = country.id == selected ? 1.8 : .4,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AllocationMapPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.data != data ||
      oldDelegate.selected != selected ||
      oldDelegate.scheme != scheme;
}
