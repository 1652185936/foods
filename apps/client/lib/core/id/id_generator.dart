import 'package:uuid/uuid.dart';

abstract interface class IdGenerator {
  String next();
}

final class UuidV7IdGenerator implements IdGenerator {
  UuidV7IdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String next() => _uuid.v7();
}
