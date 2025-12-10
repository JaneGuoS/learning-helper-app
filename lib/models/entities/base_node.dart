abstract class BaseNode {
  final String id;
  String title;
  String description;

  BaseNode({
    required this.id,
    required this.title,
    this.description = '',
  });
}