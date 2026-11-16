import 'calendar_data.dart';

/// Google event color IDs are also used by tasks stored only on this device.
const taskColorNames = <String, String>{
  '1': 'Lavender',
  '2': 'Sage',
  '3': 'Grape',
  '4': 'Flamingo',
  '5': 'Banana',
  '6': 'Tangerine',
  '7': 'Peacock',
  '8': 'Graphite',
  '9': 'Blueberry',
  '10': 'Basil',
  '11': 'Tomato',
};

final offlineTaskPalette = CalendarEventPalette(const {
  '1': CalendarEventColor('#7986CB', '#000000'),
  '2': CalendarEventColor('#33B679', '#000000'),
  '3': CalendarEventColor('#8E24AA', '#FFFFFF'),
  '4': CalendarEventColor('#E67C73', '#000000'),
  '5': CalendarEventColor('#F6BF26', '#000000'),
  '6': CalendarEventColor('#F4511E', '#000000'),
  '7': CalendarEventColor('#039BE5', '#000000'),
  '8': CalendarEventColor('#616161', '#FFFFFF'),
  '9': CalendarEventColor('#3F51B5', '#FFFFFF'),
  '10': CalendarEventColor('#0B8043', '#FFFFFF'),
  '11': CalendarEventColor('#D50000', '#FFFFFF'),
}, DateTime.utc(2026));

String taskColorName(String id) => taskColorNames[id] ?? 'Color $id';
