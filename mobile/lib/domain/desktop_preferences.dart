/// Desktop-only presentation preferences. These never control timer time.
class DesktopPreferences {
  const DesktopPreferences({this.tooltipTitles = true, this.bounds});

  final bool tooltipTitles;
  final DesktopBounds? bounds;

  DesktopPreferences copyWith({bool? tooltipTitles, DesktopBounds? bounds}) =>
      DesktopPreferences(
        tooltipTitles: tooltipTitles ?? this.tooltipTitles,
        bounds: bounds ?? this.bounds,
      );

  Map<String, Object?> toJson() => {
    'tooltipTitles': tooltipTitles,
    'bounds': bounds?.toJson(),
  };

  factory DesktopPreferences.fromJson(Map<String, dynamic> json) {
    return DesktopPreferences(
      tooltipTitles: json['tooltipTitles'] is bool
          ? json['tooltipTitles'] as bool
          : true,
      bounds: json['bounds'] == null
          ? null
          : DesktopBounds.fromJson(
              Map<String, dynamic>.from(json['bounds'] as Map),
            ),
    );
  }
}

/// Position is in virtual-desktop physical pixels; size is in logical pixels.
/// The host reselects a monitor and clamps these values before showing a window.
class DesktopBounds {
  const DesktopBounds(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  factory DesktopBounds.fromJson(Map<String, dynamic> json) {
    final values = [
      'x',
      'y',
      'width',
      'height',
    ].map((key) => json[key]).toList();
    if (values.any((value) => value is! int) ||
        (values[0] as int).abs() > 1000000 ||
        (values[1] as int).abs() > 1000000 ||
        (values[2] as int) < 200 ||
        (values[2] as int) > 32768 ||
        (values[3] as int) < 200 ||
        (values[3] as int) > 32768) {
      throw const FormatException('Invalid desktop bounds.');
    }
    return DesktopBounds(
      values[0] as int,
      values[1] as int,
      values[2] as int,
      values[3] as int,
    );
  }
}
