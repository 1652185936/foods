import '../domain/dish.dart';

const takeoutDishCatalog = <Dish>[
  Dish(
    id: 'malatang',
    name: '清爽麻辣烫',
    description: '蔬菜多一点，主食选半份，今天就吃得热乎。',
    imageAsset: 'assets/images/malatang-hero.webp',
    waitMinutes: 28,
    priceLabel: '¥25–35',
    tags: ['热乎', '可调辣', '蔬菜足'],
  ),
  Dish(
    id: 'chicken-salad',
    name: '鸡胸牛油果沙拉',
    description: '清爽不寡淡，适合想吃轻一点的午餐。',
    imageAsset: 'assets/images/chicken-salad.webp',
    waitMinutes: 22,
    priceLabel: '¥30–42',
    tags: ['高蛋白', '清爽', '轻食'],
  ),
  Dish(
    id: 'tomato-rice',
    name: '番茄鸡蛋盖饭',
    description: '酸甜下饭，熟悉的味道不用纠结。',
    imageAsset: 'assets/images/tomato-eggs-hero.webp',
    waitMinutes: 25,
    priceLabel: '¥18–28',
    tags: ['家常', '酸甜', '省心'],
  ),
  Dish(
    id: 'oats-bowl',
    name: '燕麦水果酸奶碗',
    description: '蓝莓、香蕉和燕麦，适合早餐或轻晚餐。',
    imageAsset: 'assets/images/oats-breakfast.webp',
    waitMinutes: 18,
    priceLabel: '¥22–32',
    tags: ['早餐', '低负担', '水果'],
  ),
];
