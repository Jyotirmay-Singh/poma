import 'package:flutter/material.dart';

import '../domain/calendar_colors.dart';
import '../domain/calendar_data.dart';
import 'day_clock_dial.dart';
import 'design_tokens.dart';

class TaskColorPicker extends StatelessWidget {
  const TaskColorPicker({
    required this.value,
    required this.palette,
    required this.onChanged,
    this.error,
    super.key,
  });

  final String? value;
  final CalendarEventPalette palette;
  final ValueChanged<String?>? onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: Theme.of(context).textTheme.labelLarge),
        if (value != null && !palette.colors.containsKey(value))
          const Text('Existing event color'),
        const SizedBox(height: PomaSpace.xs),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Calendar default'),
              selected: value == null,
              onSelected: onChanged == null ? null : (_) => onChanged!(null),
            ),
            for (final entry in palette.colors.entries)
              Builder(
                builder: (context) {
                  final fill = clockColor(
                    entry.value.background,
                    colors.primary,
                  );
                  final selected = value == entry.key;
                  final name = taskColorName(entry.key);
                  return Semantics(
                    label: name,
                    selected: selected,
                    button: true,
                    enabled: onChanged != null,
                    child: Tooltip(
                      message: name,
                      child: InkResponse(
                        key: ValueKey('task-color-${entry.key}'),
                        radius: 24,
                        onTap: onChanged == null
                            ? null
                            : () => onChanged!(entry.key),
                        child: SizedBox.square(
                          dimension: 48,
                          child: Center(
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: fill,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? colors.onSurface : fill,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: selected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: clockInk(fill),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        if (error != null) Text(error!, style: TextStyle(color: colors.error)),
      ],
    );
  }
}
