import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/planner_controller.dart';
import '../domain/calendar_data.dart';
import 'calendar_tasks.dart';
import 'day_clock_dial.dart';

class CalendarSidebar extends StatefulWidget {
  const CalendarSidebar({
    required this.planner,
    required this.showDeviceTasks,
    required this.onDeviceTasksChanged,
    required this.onCreate,
    super.key,
  });
  final PlannerController planner;
  final bool showDeviceTasks;
  final ValueChanged<bool> onDeviceTasksChanged;
  final VoidCallback onCreate;

  @override
  State<CalendarSidebar> createState() => _CalendarSidebarState();
}

class _CalendarSidebarState extends State<CalendarSidebar> {
  DateTime? _month;

  Widget _miniCalendar() {
    final planner = widget.planner;
    final day = planner.selectedDate;
    final month = _month ?? DateTime(day.year, day.month);
    final localizations = MaterialLocalizations.of(context);
    final firstWeekday = localizations.firstDayOfWeekIndex;
    final offset = (month.weekday % 7 - firstWeekday + 7) % 7;
    final first = DateTime(month.year, month.month, 1 - offset);
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM().format(month),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final direction in [-1, 1])
              IconButton(
                tooltip: direction < 0
                    ? 'Previous mini-calendar month'
                    : 'Next mini-calendar month',
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => setState(
                  () => _month = DateTime(month.year, month.month + direction),
                ),
                icon: Icon(
                  direction < 0 ? Icons.chevron_left : Icons.chevron_right,
                  size: 20,
                ),
              ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    localizations.narrowWeekdays[(i + firstWeekday) % 7],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final date = DateTime(first.year, first.month, first.day + index);
            final selected =
                date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
            final now = planner.currentTime.toLocal();
            final today = DateUtils.isSameDay(date, now);
            return Semantics(
              label: DateFormat.yMMMMEEEEd().format(date),
              selected: selected,
              child: Tooltip(
                message: DateFormat.yMMMEd().format(date),
                child: InkResponse(
                  onTap: () {
                    setState(() => _month = null);
                    planner.browse(
                      CalendarDate(date.year, date.month, date.day),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? colors.primary : null,
                      border: today && !selected
                          ? Border.all(color: colors.primary)
                          : null,
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        '${date.day}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected
                              ? colors.onPrimary
                              : date.month == month.month
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final planner = widget.planner;
    final reader = planner.remoteReader;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('planner-add-task'),
            onPressed: planner.ready ? widget.onCreate : null,
            icon: const Icon(Icons.add_rounded, size: 26),
            label: const Text('Create task'),
          ),
        ),
        const SizedBox(height: 24),
        if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
          _miniCalendar()
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('Choose date'),
            onPressed: () async {
              final date = planner.selectedDate;
              final chosen = await showDatePicker(
                context: context,
                initialDate: DateTime(date.year, date.month, date.day),
                firstDate: DateTime(1602),
                lastDate: DateTime(9998, 12, 31),
              );
              if (chosen != null) {
                planner.browse(
                  CalendarDate(chosen.year, chosen.month, chosen.day),
                );
              }
            },
          ),
        const SizedBox(height: 16),
        CalendarTaskTray(planner: planner),
        const SizedBox(height: 16),
        Text('My calendars', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('On this device'),
          value: widget.showDeviceTasks,
          onChanged: (value) => widget.onDeviceTasksChanged(value!),
        ),
        if (reader != null)
          for (final source in planner.sources.where(
            (source) => source.readable,
          ))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: clockColor(
                safeCalendarColor(source.backgroundColor),
                Theme.of(context).colorScheme.primary,
              ),
              title: Text(source.name),
              checkColor: clockInk(
                clockColor(
                  safeCalendarColor(source.backgroundColor),
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              value: reader.selected.contains(source.id),
              onChanged: (selected) {
                final ids = {...reader.selected};
                if (selected == true) {
                  ids.add(source.id);
                } else {
                  ids.remove(source.id);
                }
                reader.select(ids);
              },
            ),
      ],
    );
  }
}
