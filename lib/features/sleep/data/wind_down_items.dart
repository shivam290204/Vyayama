/// One item of the wind-down checklist.
class WindDownItem {
  /// Creates an item.
  const WindDownItem(this.id, this.title);

  /// Stable id.
  final String id;

  /// Text shown to the user.
  final String title;
}

/// The wind-down checklist (general habits, not medical advice).
const List<WindDownItem> kWindDownItems = <WindDownItem>[
  WindDownItem('dim_lights', 'Dim the lights'),
  WindDownItem('phone_away', 'Put your phone away or use Do Not Disturb'),
  WindDownItem('stretch', 'Stretch gently or take a few slow breaths'),
  WindDownItem('prepare', 'Get tomorrow\'s clothes or bag ready'),
  WindDownItem('warm_drink', 'Have a warm, caffeine-free drink if you like'),
  WindDownItem('room', 'Keep your room cool and quiet'),
];
