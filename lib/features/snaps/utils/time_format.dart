/// "just now", "5m ago", "3h ago".
String timeAgo(DateTime time, DateTime nowUtc) {
  final d = nowUtc.difference(time.toUtc());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

/// "Expires in 5h 20m".
String expiresIn(DateTime expiresAt, DateTime nowUtc) {
  final d = expiresAt.toUtc().difference(nowUtc);
  if (d.isNegative) return 'Expired';
  if (d.inHours >= 1) return 'Expires in ${d.inHours}h ${d.inMinutes.remainder(60)}m';
  return 'Expires in ${d.inMinutes}m';
}
