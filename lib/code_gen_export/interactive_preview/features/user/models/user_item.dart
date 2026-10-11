class UserItemModel {
  final String title;
  final String subtitle;

  const UserItemModel({
    required this.title,
    required this.subtitle,
  });

  static List<UserItemModel> demoData() {
    return const [
      UserItemModel(title: 'Sample 1', subtitle: 'Description 1'),
      UserItemModel(title: 'Sample 2', subtitle: 'Description 2'),
      UserItemModel(title: 'Sample 3', subtitle: 'Description 3'),
        ];
  }
  @override
  String toString() => title;
}
