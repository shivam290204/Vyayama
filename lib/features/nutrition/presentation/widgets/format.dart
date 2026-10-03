/// Formats a number with thousands separators, for example `1,850`.
String formatKcal(int value) => value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
