import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/appearance_controller.dart';

enum NovaStatus { success, warning, critical, information, neutral }

class NovaPageHeader extends StatelessWidget {
  const NovaPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      NovaSpacing.md,
      NovaSpacing.md,
      NovaSpacing.md,
      NovaSpacing.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.displayMedium),
              if (subtitle != null) ...[
                const SizedBox(height: NovaSpacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class NovaSectionHeader extends StatelessWidget {
  const NovaSectionHeader({super.key, required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      ?action,
    ],
  );
}

class NovaCard extends StatelessWidget {
  const NovaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NovaSpacing.md),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class NovaMetricTile extends StatelessWidget {
  const NovaMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.detail,
  });
  final String label;
  final String value;
  final IconData? icon;
  final String? detail;
  @override
  Widget build(BuildContext context) => NovaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Icon(
            icon,
            size: NovaIconSize.md,
            color: Theme.of(context).colorScheme.primary,
          ),
        const SizedBox(height: NovaSpacing.xs),
        Text(
          value,
          style: NovaTypography.data.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        if (detail != null)
          Text(detail!, style: Theme.of(context).textTheme.labelMedium),
      ],
    ),
  );
}

class NovaActionRow extends StatelessWidget {
  const NovaActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 52,
    enabled: enabled,
    leading: leading,
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing:
        trailing ?? const Icon(Icons.chevron_right, size: NovaIconSize.md),
    onTap: enabled ? onTap : null,
  );
}

class NovaStatusBadge extends StatelessWidget {
  const NovaStatusBadge({
    super.key,
    required this.label,
    this.status = NovaStatus.neutral,
    this.icon,
  });
  final String label;
  final NovaStatus status;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      NovaStatus.success => NovaColors.success,
      NovaStatus.warning => NovaColors.warning,
      NovaStatus.critical => NovaColors.critical,
      NovaStatus.information => NovaColors.information,
      NovaStatus.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(NovaRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.xs,
          vertical: NovaSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: NovaIconSize.sm, color: color),
              const SizedBox(width: NovaSpacing.xxs),
            ],
            Text(label, style: NovaTypography.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class NovaTimelineItem {
  const NovaTimelineItem({
    required this.title,
    this.subtitle,
    this.time,
    this.status = NovaStatus.neutral,
  });
  final String title;
  final String? subtitle;
  final String? time;
  final NovaStatus status;
}

class NovaTimeline extends StatelessWidget {
  const NovaTimeline({super.key, required this.items});
  final List<NovaTimelineItem> items;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i++)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (i != items.length - 1)
                      Expanded(
                        child: VerticalDivider(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: NovaSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i].title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (items[i].subtitle != null)
                              Text(
                                items[i].subtitle!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      if (items[i].time != null)
                        Text(
                          items[i].time!,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class NovaButton extends StatelessWidget {
  const NovaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: icon == null
        ? const SizedBox.shrink()
        : Icon(icon, size: NovaIconSize.md),
    label: Text(label),
    style: destructive
        ? FilledButton.styleFrom(backgroundColor: NovaColors.critical)
        : null,
  );
}

class NovaIconButton extends StatelessWidget {
  const NovaIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon),
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
  );
}

class NovaTextField extends StatelessWidget {
  const NovaTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.onChanged,
    this.obscureText = false,
    this.enabled = true,
    this.prefixIcon,
  });
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final bool enabled;
  final IconData? prefixIcon;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    obscureText: obscureText,
    enabled: enabled,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
    ),
  );
}

class NovaSearchField extends StatelessWidget {
  const NovaSearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
  });
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => NovaTextField(
    controller: controller,
    hint: hint,
    onChanged: onChanged,
    prefixIcon: Icons.search,
  );
}

class NovaFilterBar extends StatelessWidget {
  const NovaFilterBar({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelected,
  });
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final filter in filters)
          Padding(
            padding: const EdgeInsets.only(right: NovaSpacing.xs),
            child: FilterChip(
              label: Text(filter),
              selected: filter == selected,
              onSelected: (_) => onSelected(filter),
            ),
          ),
      ],
    ),
  );
}

class NovaEmptyState extends StatelessWidget {
  const NovaEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) =>
      _NovaState(icon: icon, title: title, message: message, action: action);
}

class NovaErrorState extends StatelessWidget {
  const NovaErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => _NovaState(
    icon: Icons.error_outline,
    iconColor: NovaColors.critical,
    title: title,
    message: message,
    action: onRetry == null
        ? null
        : NovaButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
  );
}

class NovaLoadingState extends StatelessWidget {
  const NovaLoadingState({super.key, this.label = 'Loading…'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(label: label, child: const CircularProgressIndicator()),
  );
}

class _NovaState extends StatelessWidget {
  const _NovaState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor,
  });
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(NovaSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: NovaSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (message != null) ...[
            const SizedBox(height: NovaSpacing.xs),
            Text(message!, textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: NovaSpacing.md),
            action!,
          ],
        ],
      ),
    ),
  );
}

class NovaConfirmSheet extends StatelessWidget {
  const NovaConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.destructive = false,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (_) => NovaConfirmSheet(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          destructive: destructive,
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(NovaSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: NovaSpacing.xs),
          Text(message),
          const SizedBox(height: NovaSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: NovaSpacing.xs),
              NovaButton(
                label: confirmLabel,
                destructive: destructive,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class NovaAppearanceSelector extends StatelessWidget {
  const NovaAppearanceSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppearanceController>();
    return Semantics(
      label: 'Appearance',
      child: SegmentedButton<NovaAppearance>(
        segments: const [
          ButtonSegment(
            value: NovaAppearance.system,
            icon: Icon(Icons.brightness_auto_outlined),
            label: Text('System'),
          ),
          ButtonSegment(
            value: NovaAppearance.light,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Light'),
          ),
          ButtonSegment(
            value: NovaAppearance.dark,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Dark'),
          ),
        ],
        selected: {controller.appearance},
        onSelectionChanged: (value) => controller.select(value.single),
        showSelectedIcon: false,
      ),
    );
  }
}
