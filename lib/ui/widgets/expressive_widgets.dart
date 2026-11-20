import 'package:flutter/material.dart';

import '../../l10n/strings.dart';

class ExpressiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final BorderSide? borderSide;

  const ExpressiveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.color,
    this.onTap,
    this.borderSide,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final bg = color ?? cs.surfaceContainerLowest;
    final side = borderSide ??
        (isDark
            ? BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.24),
                width: 1,
              )
            : BorderSide.none);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: side == BorderSide.none ? null : Border.fromBorderSide(side),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D131B2E),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x05131B2E),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );
  }
}

class SquircleIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double radius;
  final double iconSize;

  const SquircleIcon({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 48,
    this.radius = 16,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

class ExpressivePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double fontSize;

  const ExpressivePill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.fontWeight = FontWeight.w600,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.onTap,
    this.fontSize = 11.5,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: fontWeight,
                    fontSize: fontSize,
                  ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: backgroundColor,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(onTap: onTap, child: content)
          : content,
    );
  }
}

class ExpressiveSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const ExpressiveSegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

class ExpressiveSegmentedControl<T> extends StatelessWidget {
  final List<ExpressiveSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;
  final Color? activeColor;
  final Color? activeForeground;
  final EdgeInsetsGeometry itemPadding;

  const ExpressiveSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = true,
    this.activeColor,
    this.activeForeground,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeBg = activeColor ?? cs.primary;
    final activeFg = activeForeground ?? cs.onPrimary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: segments.map((seg) {
          final isSelected = seg.value == selected;
          final pill = Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (!isSelected) onChanged(seg.value);
              },
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: itemPadding,
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeBg.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (seg.icon != null) ...[
                      Icon(
                        seg.icon,
                        size: 16,
                        color: isSelected ? activeFg : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        seg.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color:
                                  isSelected ? activeFg : cs.onSurfaceVariant,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return expand ? Expanded(child: pill) : pill;
        }).toList(),
      ),
    );
  }
}

class InhaEmblem extends StatelessWidget {
  final double size;
  final double radius;
  final bool showVerifiedBadge;

  const InhaEmblem({
    super.key,
    this.size = 40,
    this.radius = 12,
    this.showVerifiedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emblem = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryFixed,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(radius * 0.65),
            border: Border.all(
              color: cs.primary.withValues(alpha: 0.18),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.school_rounded,
            size: size * 0.44,
            color: cs.primary,
          ),
        ),
      ),
    );

    if (!showVerifiedBadge) return emblem;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        emblem,
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: cs.surface, width: 2.5),
            ),
            child: Icon(Icons.check_rounded, size: 12, color: cs.onPrimary),
          ),
        ),
      ],
    );
  }
}

class ExpressiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String overline;
  final bool showBack;
  final List<Widget>? actions;

  const ExpressiveAppBar({
    super.key,
    required this.title,
    this.overline = 'IUT PORTAL',
    this.showBack = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: 63,
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 4 : 16,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: Row(
        children: [
          const InhaEmblem(size: 36, radius: 11),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  overline,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class CircleActionButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? backgroundColor;
  final Color? iconColor;

  const CircleActionButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.loading = false,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.surfaceContainerHigh;
    final fg = iconColor ?? cs.onSurfaceVariant;

    final btn = Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

class HeroGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const HeroGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 28,
  });

  static Color _ensureDarkStop(Color candidate, Color fallbackDeep) {
    if (ThemeData.estimateBrightnessForColor(candidate) == Brightness.dark) {
      return candidate;
    }
    return Color.lerp(candidate, fallbackDeep, 0.72)!;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final c1 = isDark
        ? Color.lerp(cs.primaryContainer, const Color(0xFF002475), 0.45)!
        : _ensureDarkStop(cs.primary, const Color(0xFF0037B0));
    final c2 = isDark
        ? Color.lerp(cs.primaryContainer, const Color(0xFF1741B5), 0.35)!
        : _ensureDarkStop(cs.primaryContainer, const Color(0xFF1D4ED8));
    final c3 = isDark
        ? Color.lerp(cs.secondaryContainer, const Color(0xFF004C7A), 0.55)!
        : _ensureDarkStop(cs.secondary, const Color(0xFF006398));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2, c3],
        ),
        boxShadow: [
          BoxShadow(
            color: c2.withValues(alpha: isDark ? 0.32 : 0.24),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -28,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              left: -24,
              bottom: -36,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showVerifiedBadge;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.backgroundColor,
    this.foregroundColor,
    this.showVerifiedBadge = false,
  });

  String get _initials {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return '';
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primaryFixed;
    final fg = foregroundColor ?? cs.onPrimaryFixed;
    final initials = _initials;

    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: initials.isEmpty
            ? Icon(Icons.person_rounded, size: size * 0.55, color: fg)
            : Text(
                initials,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.36,
                    ),
              ),
      ),
    );

    if (!showVerifiedBadge) return circle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: cs.surfaceContainerLowest, width: 2),
            ),
            child: Icon(Icons.check_rounded, size: 10, color: cs.onPrimary),
          ),
        ),
      ],
    );
  }
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

IconData iconForFileName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
  if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) {
    return Icons.folder_zip_rounded;
  }
  if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
    return Icons.slideshow_rounded;
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    return Icons.description_rounded;
  }
  if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) {
    return Icons.table_chart_rounded;
  }
  if (lower.endsWith('.cpp') ||
      lower.endsWith('.c') ||
      lower.endsWith('.py') ||
      lower.endsWith('.dart') ||
      lower.endsWith('.java') ||
      lower.endsWith('.js') ||
      lower.endsWith('.json')) {
    return Icons.code_rounded;
  }
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp')) {
    return Icons.image_rounded;
  }
  return Icons.insert_drive_file_rounded;
}

Color colorForFileName(String name, ColorScheme cs) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return cs.error;
  if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) {
    return cs.primary;
  }
  if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return cs.tertiary;
  return cs.secondary;
}

String formatRelativeTime(int epochMs, S s) {
  if (epochMs <= 0) return '';
  final diff = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(epochMs));
  if (diff.inMinutes < 1) return s.justNow;
  if (diff.inHours < 1) return s.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return s.hoursAgo(diff.inHours);
  return s.daysAgo(diff.inDays);
}
