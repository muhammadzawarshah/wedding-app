import 'dart:async';
import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/passport_background.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // Venue details come from the admin "Wedding settings" panel via the backend.
  late final Future<WeddingOverview> _overview = ApiService.instance
      .fetchOverview();

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Location',
        child: FutureBuilder<WeddingOverview>(
          future: _overview,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final info = snapshot.data ?? WeddingOverview.fallback;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  title: info.venueName,
                  subtitle: 'Venue details and map access for guests.',
                ),
                const SizedBox(height: 16),
                VenueMapPanel(
                  venueName: info.venueName,
                  venueAddress: info.venueAddress,
                  mapUrl: info.mapUrl,
                  venueUrl: info.venueUrl,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class VenueMapPanel extends StatelessWidget {
  const VenueMapPanel({
    required this.venueName,
    required this.venueAddress,
    required this.mapUrl,
    this.venueUrl = '',
    super.key,
  });

  final String venueName;
  final String venueAddress;
  final String mapUrl;
  final String venueUrl;

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.tryParse(venueUrl.trim());
    if (uri == null || !uri.hasScheme) return;
    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
      LaunchMode.inAppBrowserView,
    ]) {
      try {
        if (await launchUrl(uri, mode: mode)) return;
      } catch (_) {
        // Try the next launch mode.
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open the venue website.')),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    final opened = await _openMapLocation(mapUrl, venueAddress, venueName);
    if (opened || !context.mounted) return;

    if (_mapQuery(mapUrl, venueAddress, venueName) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No map link is available yet.')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open the map.')));
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.passportGold.withValues(alpha: 0.18),
                foregroundColor: AppColors.deepInk,
                child: const Icon(Icons.location_on),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Venue map',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            venueAddress.isEmpty ? venueName : venueAddress,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          VenueMapPreview(
            venueName: venueName,
            venueAddress: venueAddress,
            mapUrl: mapUrl,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _openMap(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Maps'),
          ),
          if (venueUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openWebsite(context),
              icon: const Icon(Icons.public),
              label: const Text('Venue website'),
            ),
          ],
        ],
      ),
    );
  }
}

class VenueMapPreview extends StatefulWidget {
  const VenueMapPreview({
    required this.venueName,
    required this.venueAddress,
    required this.mapUrl,
    super.key,
  });

  final String venueName;
  final String venueAddress;
  final String mapUrl;

  @override
  State<VenueMapPreview> createState() => _VenueMapPreviewState();
}

class _VenueMapPreviewState extends State<VenueMapPreview> {
  WebViewController? _controller;
  Timer? _loadingTimeout;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadGoogleMap();
  }

  @override
  void didUpdateWidget(covariant VenueMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapUrl != widget.mapUrl ||
        oldWidget.venueAddress != widget.venueAddress ||
        oldWidget.venueName != widget.venueName) {
      _loadGoogleMap();
    }
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  void _loadGoogleMap() {
    _loadingTimeout?.cancel();
    final embedUri = _googleMapsEmbedUri(
      widget.mapUrl,
      widget.venueAddress,
      widget.venueName,
    );
    if (embedUri == null) {
      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
      return;
    }

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              if (mounted && error.isForMainFrame == true) {
                setState(() {
                  _loading = false;
                  _failed = true;
                });
              }
            },
          ),
        )
        ..loadHtmlString(_googleMapsEmbedHtml(embedUri));

      setState(() {
        _controller = controller;
        _loading = true;
        _failed = false;
      });
      _loadingTimeout = Timer(const Duration(seconds: 12), () {
        if (!mounted || !_loading) return;
        setState(() {
          _loading = false;
          _failed = true;
        });
      });
    } catch (_) {
      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _openMapLocation(
          widget.mapUrl,
          widget.venueAddress,
          widget.venueName,
        ),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null && !_failed)
                WebViewWidget(controller: _controller!)
              else
                _MapFallback(
                  venueName: widget.venueName,
                  venueAddress: widget.venueAddress,
                ),
              if (_loading)
                const ColoredBox(
                  color: Colors.white70,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  const _MapFallback({required this.venueName, required this.venueAddress});

  final String venueName;
  final String venueAddress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.paperBlue.withValues(alpha: 0.65),
      padding: const EdgeInsets.all(18),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              venueAddress.isEmpty ? venueName : venueAddress,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _openMapLocation(
  String mapUrl,
  String address,
  String venueName,
) async {
  final coordinates = _coordinatesFromMapUrl(mapUrl);
  if (defaultTargetPlatform == TargetPlatform.android && coordinates != null) {
    final latLng = '${coordinates.latitude},${coordinates.longitude}';
    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: 'google.navigation:q=$latLng',
      package: 'com.google.android.apps.maps',
    );
    try {
      await intent.launch();
      return true;
    } catch (_) {
      // Fall back to generic map/browser URLs below.
    }
  }

  for (final target in _mapLaunchUris(mapUrl, address, venueName)) {
    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        final opened = await launchUrl(target, mode: mode);
        if (opened) return true;
      } catch (_) {
        // Try the next map target / launch mode.
      }
    }
  }

  return false;
}

List<Uri> _mapLaunchUris(String mapUrl, String address, String venueName) {
  final query = _mapQuery(mapUrl, address, venueName);
  if (query == null) return const [];

  final targets = <Uri>[];
  final coordinates = _coordinatesFromMapUrl(mapUrl);
  if (coordinates != null) {
    final latLng = '${coordinates.latitude},${coordinates.longitude}';
    final label = Uri.encodeComponent(venueName.trim());
    final suffix = label.isEmpty ? latLng : '$latLng($label)';
    targets.add(Uri.parse('geo:0,0?q=$suffix'));
  }

  final raw = Uri.tryParse(mapUrl.trim());
  if (raw != null && raw.hasScheme) targets.add(raw);

  targets.add(
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
  );
  targets.add(Uri.https('maps.google.com', '/', {'q': query}));

  return targets;
}

_MapCoordinates? _coordinatesFromMapUrl(String url) {
  final atMatch = RegExp(
    r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  ).firstMatch(url);
  if (atMatch != null) {
    return _MapCoordinates(
      double.parse(atMatch.group(1)!),
      double.parse(atMatch.group(2)!),
    );
  }

  final placeMatch = RegExp(
    r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
  ).firstMatch(url);
  if (placeMatch != null) {
    return _MapCoordinates(
      double.parse(placeMatch.group(1)!),
      double.parse(placeMatch.group(2)!),
    );
  }

  return null;
}

Uri? _googleMapsEmbedUri(String mapUrl, String address, String venueName) {
  final query = _mapQuery(mapUrl, address, venueName);
  if (query == null) return null;
  return Uri.https('maps.google.com', '/maps', {
    'q': query,
    'z': '15',
    'output': 'embed',
  });
}

String _googleMapsEmbedHtml(Uri embedUri) {
  final src = const HtmlEscape().convert(embedUri.toString());
  return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body, iframe {
      width: 100%;
      height: 100%;
      margin: 0;
      border: 0;
      overflow: hidden;
    }
  </style>
</head>
<body>
  <iframe
    src="$src"
    loading="lazy"
    allowfullscreen
    referrerpolicy="no-referrer-when-downgrade">
  </iframe>
</body>
</html>
''';
}

String? _mapQuery(String mapUrl, String address, String venueName) {
  final coordinates = _coordinatesFromMapUrl(mapUrl);
  if (coordinates != null) {
    return '${coordinates.latitude},${coordinates.longitude}';
  }

  final addressText = address.trim();
  final venueText = venueName.trim();
  if (venueText.isNotEmpty && addressText.isNotEmpty) {
    return '$venueText, $addressText';
  }
  if (addressText.isNotEmpty) return addressText;
  if (venueText.isNotEmpty) return venueText;
  return null;
}

class _MapCoordinates {
  const _MapCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
