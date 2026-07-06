import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown at the top of every screen when the production backend can't be
/// reached, so guests know live content may be temporarily unavailable.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppConfig.backendOnline,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        return Material(
          color: Colors.orange.shade800,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Connection issue. Please try again shortly.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.subtitle,
    this.light = true,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// When true (default) the title is styled for the dark photo background.
  /// Pass false when placing it on a light surface (e.g. inside a card).
  final bool light;

  @override
  Widget build(BuildContext context) {
    final titleColor = light ? Colors.white : AppColors.deepInk;
    final subtitleColor = light
        ? Colors.white.withValues(alpha: 0.82)
        : AppColors.mutedInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: titleColor),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
          ),
        ],
      ],
    );
  }
}

class PassportHero extends StatelessWidget {
  const PassportHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: SectionCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 0.78,
                  child: Image.asset(
                    'assets/images/couple_login.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Column(
                    children: [
                      Text(
                        'PASSPORT INVITATION',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aija & Abhi',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LinkPanel extends StatelessWidget {
  const LinkPanel({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final String url;
  final IconData icon;

  Future<void> _openLink(BuildContext context) async {
    final uri = _normalisedExternalUri(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('This link is not valid.')));
      return;
    }

    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
      LaunchMode.inAppBrowserView,
    ]) {
      try {
        final opened = await launchUrl(uri, mode: mode);
        if (opened) return;
      } catch (_) {
        // Try the next launch mode.
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open this link.')));
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.passportGold.withValues(alpha: 0.18),
            foregroundColor: AppColors.deepInk,
            child: Icon(icon),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 16),
          SelectableText(
            url,
            style: const TextStyle(
              color: AppColors.deepInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openLink(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Link'),
          ),
        ],
      ),
    );
  }
}

Uri? _normalisedExternalUri(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final withScheme = RegExp(r'^[a-zA-Z][a-zA-Z\d+\-.]*://').hasMatch(trimmed)
      ? trimmed
      : 'https://$trimmed';
  return Uri.tryParse(withScheme);
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
