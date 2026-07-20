class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.imageAsset,
    required this.waitMinutes,
    required this.priceLabel,
    required this.tags,
  });

  final String id;
  final String name;
  final String description;
  final String imageAsset;
  final int waitMinutes;
  final String priceLabel;
  final List<String> tags;
}
