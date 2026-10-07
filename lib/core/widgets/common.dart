import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onPressed != null;
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: enabled
              ? (destructive ? riskGradient('critical') : AppGradients.primary)
              : null,
          color: enabled ? null : AppColors.surfaceHigh,
        ),
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: AppColors.muted,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.highlight = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: highlight ? AppGradients.alert : AppGradients.surface,
        border: Border.all(color: highlight ? AppColors.redBright : AppColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

/// Section label used to break long screens into readable groups.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.action});

  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                fontSize: 12,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

/// Compact pill for one fact, used instead of long status lists.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: riskGradient(level),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class MetricBlock extends StatelessWidget {
  const MetricBlock({super.key, required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: accent ? AppGradients.primary : AppGradients.surface,
          border: Border.all(color: accent ? AppColors.redBright : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: accent ? Colors.white70 : AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
