import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';

/// A single selectable filter option (value stored, label shown).
class AdminFilterOption {
  final String value;
  final String label;
  const AdminFilterOption(this.value, this.label);
}

/// Horizontal pill selector for a single-choice filter (e.g. status).
/// Wraps to multiple lines on narrow widths.
class AdminChoiceChips extends StatelessWidget {
  final List<AdminFilterOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const AdminChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSel = o.value == selected;
        return GestureDetector(
          onTap: () => onSelected(o.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? AppColors.primary : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isSel ? AppColors.primary : AppColors.outlineVariant,
              ),
            ),
            child: Text(
              o.label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                color: isSel ? AppColors.onPrimary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Bordered dropdown for an optional single-choice filter. A `null` value shows
/// [hint] and represents "all".
class AdminFilterDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<AdminFilterOption> options;
  final ValueChanged<String?> onChanged;
  final IconData? icon;

  const AdminFilterDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint, style: const TextStyle(fontSize: 13)),
              underline: const SizedBox.shrink(),
              isExpanded: true,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(hint, style: const TextStyle(fontSize: 13)),
                ),
                ...options.map(
                  (o) => DropdownMenuItem<String>(
                    value: o.value,
                    child: Text(
                      o.label,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
