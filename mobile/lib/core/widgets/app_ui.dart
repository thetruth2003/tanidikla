import 'package:ankara_proje/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    required this.title,
    this.leading,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 48, child: leading),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 48, child: trailing),
          ),
        ],
      ),
    );
  }
}

class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.height = 44,
    super.key,
  });

  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.aquaSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.aqua),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(segment.value),
                    borderRadius: BorderRadius.circular(15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        gradient: selected == segment.value
                            ? const LinearGradient(
                                colors: [
                                  AppColors.turquoiseDark,
                                  AppColors.turquoise,
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: selected == segment.value
                            ? const [
                                BoxShadow(
                                  color: Color(0x2418A7A0),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (segment.icon != null) ...[
                            Icon(
                              segment.icon,
                              size: 17,
                              color: selected == segment.value
                                  ? Colors.white
                                  : AppColors.ink,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              segment.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: selected == segment.value
                                        ? Colors.white
                                        : AppColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppStepProgress extends StatelessWidget {
  const AppStepProgress({
    required this.currentStep,
    required this.labels,
    super.key,
  });

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 1,
                          color: index <= currentStep
                              ? AppColors.turquoise
                              : AppColors.outline,
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index <= currentStep
                            ? AppColors.turquoise
                            : AppColors.outline,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index <= currentStep
                              ? Colors.white
                              : AppColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (index < labels.length - 1)
                      Expanded(
                        child: Container(
                          height: 1,
                          color: index < currentStep
                              ? AppColors.turquoise
                              : AppColors.outline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: index <= currentStep
                        ? AppColors.ink
                        : AppColors.muted,
                    fontWeight: index == currentStep
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    this.size = 52,
    this.backgroundColor = AppColors.aqua,
    this.foregroundColor = AppColors.turquoiseDark,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: foregroundColor, size: size * .48),
    );
  }
}

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    required this.label,
    this.icon,
    this.backgroundColor = AppColors.aqua,
    this.foregroundColor = AppColors.turquoiseDeep,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AppInfoBanner extends StatelessWidget {
  const AppInfoBanner({
    required this.title,
    required this.message,
    this.icon = Icons.shield_outlined,
    this.trailing,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      color: AppColors.aquaSoft,
      borderColor: AppColors.aqua,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconBadge(icon: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: AppColors.aquaSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 50, color: AppColors.turquoiseDark),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
