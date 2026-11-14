import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Circular, activity-scoped brand advertisements for the Silsila app.
/// The registered Silsila app identity remains owned by the app shell
/// (assets/images/silsila_logo.png); this widget only renders advertiser logos.
class SilsilaBrandAdsCarousel extends StatefulWidget {
  const SilsilaBrandAdsCarousel({
    super.key,
    this.activityCode,
    this.diameter = 148,
    this.autoScroll = true,
  });

  final String? activityCode;
  final double diameter;
  final bool autoScroll;

  @override
  State<SilsilaBrandAdsCarousel> createState() => _SilsilaBrandAdsCarouselState();
}

class _SilsilaBrandAdsCarouselState extends State<SilsilaBrandAdsCarousel> {
  final ScrollController _controller = ScrollController();
  Timer? _ticker;
  List<Map<String, dynamic>> _brands = const [];
  bool _loading = true;
  String? _error;

  static const _purple = Color(0xFF3E007D);
  static const _orange = Color(0xFFFFA015);
  static const _pink = Color(0xFFFF27C3);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SilsilaBrandAdsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activityCode != widget.activityCode) {
      _ticker?.cancel();
      _controller.jumpTo(0);
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_silsila_public_ticker_ads',
        params: {'p_activity_code': widget.activityCode},
      );
      if (!mounted) return;
      setState(() {
        _brands = (rows as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
        _loading = false;
      });
      _startTicker();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل إعلانات البراندات';
      });
    }
  }

  Uint8List? _bytes(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    final hex = raw.startsWith(r'\\x') ? raw.substring(2) : raw;
    if (hex.isEmpty || hex.length.isOdd) return null;
    try {
      return Uint8List.fromList(List<int>.generate(
        hex.length ~/ 2,
        (index) => int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16),
      ));
    } catch (_) {
      return null;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    if (!widget.autoScroll || _brands.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _ticker = Timer.periodic(const Duration(milliseconds: 24), (_) {
        if (!mounted || !_controller.hasClients) return;
        final position = _controller.position;
        final loopExtent = _brands.length * (widget.diameter + 22);
        if (position.pixels >= loopExtent) {
          _controller.jumpTo(position.pixels - loopExtent);
        } else {
          _controller.jumpTo((position.pixels + .65).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ));
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _brand(Map<String, dynamic> brand) {
    final bytes = _bytes(brand['logo_data']);
    return SizedBox(
      width: widget.diameter + 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.diameter,
            height: widget.diameter,
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [_orange, _pink, _orange, _pink, _orange],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: const Color(0xFFF8F5FB),
                  child: bytes == null
                      ? const Icon(Icons.storefront_outlined, color: _purple, size: 42)
                      : Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront_outlined,
                            color: _purple,
                            size: 42,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: widget.diameter + 12,
            child: Text(
              (brand['brand_name'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _purple,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }
    if (_error != null || _brands.isEmpty) return const SizedBox.shrink();

    final looped = _brands.length > 1 ? [..._brands, ..._brands] : _brands;
    return SizedBox(
      height: widget.diameter + 38,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: looped.length,
          separatorBuilder: (_, __) => const SizedBox(width: 0),
          itemBuilder: (_, index) => _brand(looped[index]),
        ),
      ),
    );
  }
}
