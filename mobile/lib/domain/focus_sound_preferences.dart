enum FocusSoundId { off, tibetanBells, waterfall, oceanWaves, forestBirds }

/// Saved choices only. Playback authorization is deliberately never serialized.
class FocusSoundPreferences {
  const FocusSoundPreferences({
    this.sound = FocusSoundId.off,
    this.volume = .35,
    this.muted = false,
  });
  final FocusSoundId sound;
  final double volume;
  final bool muted;

  FocusSoundPreferences copyWith({
    FocusSoundId? sound,
    double? volume,
    bool? muted,
  }) => FocusSoundPreferences(
    sound: sound ?? this.sound,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'sound': sound.name,
    'volume': volume,
    'muted': muted,
  };

  factory FocusSoundPreferences.fromJson(Map<String, dynamic> json) {
    final volume = json.containsKey('volume') ? json['volume'] : .35;
    final muted = json.containsKey('muted') ? json['muted'] : false;
    final version = json.containsKey('version') ? json['version'] : 1;
    if (version is! int ||
        version != 1 ||
        volume is! num ||
        !volume.isFinite ||
        volume < 0 ||
        volume > 1 ||
        muted is! bool) {
      throw const FormatException('Invalid focus sound preferences.');
    }
    final sound = FocusSoundId.values.where(
      (s) => s.name == (json.containsKey('sound') ? json['sound'] : 'off'),
    );
    if (sound.isEmpty) throw const FormatException('Invalid focus sound.');
    return FocusSoundPreferences(
      sound: sound.single,
      volume: volume.toDouble(),
      muted: muted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FocusSoundPreferences &&
      sound == other.sound &&
      volume == other.volume &&
      muted == other.muted;
  @override
  int get hashCode => Object.hash(sound, volume, muted);
}
