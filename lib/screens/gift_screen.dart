import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/media_image.dart';
import '../widgets/passport_background.dart';

/// Guest gift screen. With payment methods configured, the guest picks a
/// currency then pays by link, QR code, or bank details. Falls back to the
/// single gift link set in Wedding settings when none are configured.
class GiftScreen extends StatefulWidget {
  const GiftScreen({super.key});

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> {
  late final Future<List<Object>> _future = Future.wait([
    ApiService.instance.fetchPaymentMethods(),
    ApiService.instance.fetchOverview(),
  ]);
  String? _currency;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link is not valid.')),
      );
      return;
    }
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open this link.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Send Gift',
        child: FutureBuilder<List<Object>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final data = snapshot.data;
            final methods = (data != null && data.isNotEmpty)
                ? data[0] as List<PaymentMethod>
                : const <PaymentMethod>[];
            final overview = (data != null && data.length > 1)
                ? data[1] as WeddingOverview
                : WeddingOverview.fallback;
            final active = methods.where((m) => m.active).toList();

            // Fallback: single gift link (legacy) or nothing configured yet.
            if (active.isEmpty) {
              if (overview.giftUrl.trim().isEmpty) {
                return const SectionCard(
                  child: Text('Gift options will appear here soon.'),
                );
              }
              return LinkPanel(
                title: 'Send a wedding gift',
                description:
                    "Tap below to open the couple's gift link and send your blessings.",
                url: overview.giftUrl,
                icon: Icons.card_giftcard,
              );
            }

            final currencies = <String>[];
            for (final m in active) {
              if (!currencies.contains(m.currency)) currencies.add(m.currency);
            }
            final selected = _currency ?? currencies.first;
            final shown = active
                .where((m) => m.currency == selected)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionTitle(
                  title: 'Send a gift',
                  subtitle:
                      'Choose a currency, then send your blessings by link, QR code, or bank transfer.',
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: DropdownButtonFormField<String>(
                    initialValue: currencies.contains(selected)
                        ? selected
                        : currencies.first,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: [
                      for (final c in currencies)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _currency = v),
                  ),
                ),
                const SizedBox(height: 12),
                for (final m in shown)
                  _MethodCard(method: m, onOpen: _open),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.method, required this.onOpen});

  final PaymentMethod method;
  final Future<void> Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (method.type == 'link')
              ElevatedButton.icon(
                onPressed: () => onOpen(method.link),
                icon: const Icon(Icons.open_in_new),
                label: Text('Pay in ${method.currency}'),
              ),
            if (method.type == 'qr' && method.qrUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MediaImage(source: method.qrUrl, width: 220, height: 220),
              ),
              const SizedBox(height: 8),
              Text('Scan to pay in ${method.currency}'),
            ],
            if (method.type == 'account' && method.accountDetails.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.passportGold.withValues(alpha: 0.4),
                  ),
                ),
                child: SelectableText(method.accountDetails),
              ),
            if (method.description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                method.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
