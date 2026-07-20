import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:swagger_parser/swagger_parser.dart';

const _generatedMarkerName = '.api-client-generated';
const _generatedMarkerContent =
    'Owned by tool/generate_api_client.dart. Do not edit this directory.\n';
const _checkDirectoryPrefix = 'ordin_api_check_';
const _checkWorkspaceMarkerName = '.ordin-api-check-workspace';
const _checkWorkspaceMarkerContent =
    'Owned by apps/client/tool/generate_api_client.dart --check.\n';
const _strictDatePattern =
    r'^[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])$';
const _httpMethods = <String>{'get', 'post', 'put', 'patch', 'delete'};
const _publicOperationIds = <String>{
  'createOtpChallenge',
  'verifyOtpChallenge',
  'refreshAuthToken',
  'getHealth',
  'getReadiness',
};

Future<void> main(List<String> arguments) async {
  try {
    final unknownArguments = arguments.where((item) => item != '--check');
    if (unknownArguments.isNotEmpty) {
      throw UsageException(
        'Unknown argument(s): ${unknownArguments.join(', ')}',
      );
    }

    final layout = _ProjectLayout.fromScript();
    await layout.validate();
    await _cleanupStaleCheckWorkspaces();
    await _readAndValidateContract(layout.contractFile);
    if (arguments.contains('--check')) {
      await _checkGeneratedOutputs(layout);
    } else {
      await _generateInPlace(layout);
    }
  } on UsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln('Usage: dart run tool/generate_api_client.dart [--check]');
    exitCode = 64;
  } catch (error) {
    stderr.writeln('API client generation failed: $error');
    exitCode = 1;
  }
}

final class _ProjectLayout {
  const _ProjectLayout({
    required this.repositoryRoot,
    required this.clientRoot,
    required this.contractFile,
    required this.generatedDirectory,
  });

  final Directory repositoryRoot;
  final Directory clientRoot;
  final File contractFile;
  final Directory generatedDirectory;

  factory _ProjectLayout.fromScript() {
    final script = path.normalize(File.fromUri(Platform.script).absolute.path);
    final clientRoot = Directory(path.dirname(path.dirname(script)));
    return _ProjectLayout.fromRepositoryRoot(
      Directory(path.dirname(path.dirname(clientRoot.path))),
    );
  }

  factory _ProjectLayout.fromRepositoryRoot(Directory repositoryRoot) {
    final clientRoot = Directory(
      path.join(repositoryRoot.path, 'apps', 'client'),
    );
    return _ProjectLayout(
      repositoryRoot: repositoryRoot,
      clientRoot: clientRoot,
      contractFile: File(
        path.join(
          repositoryRoot.path,
          'contracts',
          'openapi',
          'ordin-api-v1.json',
        ),
      ),
      generatedDirectory: Directory(
        path.join(clientRoot.path, 'lib', 'core', 'network', 'generated'),
      ),
    );
  }

  Future<void> validate() async {
    final pubspec = File(path.join(clientRoot.path, 'pubspec.yaml'));
    if (!await pubspec.exists() ||
        !await pubspec.readAsString().then(
          (contents) => contents.contains('name: foods_client'),
        )) {
      throw StateError(
        'Generator must live at apps/client/tool/generate_api_client.dart.',
      );
    }
    if (!await contractFile.exists()) {
      throw StateError('OpenAPI contract not found: ${contractFile.path}');
    }

    final expected = path.normalize(
      path.join(
        clientRoot.absolute.path,
        'lib',
        'core',
        'network',
        'generated',
      ),
    );
    final actual = path.normalize(generatedDirectory.absolute.path);
    if (!path.equals(expected, actual) ||
        !path.equals(
          path.dirname(actual),
          path.join(clientRoot.absolute.path, 'lib', 'core', 'network'),
        )) {
      throw StateError('Refusing unsafe generated directory: $actual');
    }
  }
}

Future<void> _generateInPlace(_ProjectLayout layout) async {
  await _generateSwaggerSources(layout);
  await _runDart(const [
    'run',
    'build_runner',
    'build',
  ], workingDirectory: layout.clientRoot);
  await _formatGeneratedApi(layout);
  await _validateGeneratedOutput(layout.generatedDirectory);
}

Future<void> _checkGeneratedOutputs(_ProjectLayout realLayout) async {
  final committed = await _snapshotManagedOutputs(realLayout);
  final checkRoot = await Directory.systemTemp.createTemp(
    _checkDirectoryPrefix,
  );
  final marker = File(path.join(checkRoot.path, _checkWorkspaceMarkerName));
  await marker.writeAsString(_checkWorkspaceMarkerContent, flush: true);

  try {
    await _copyCheckWorkspace(realLayout, checkRoot);
    final checkLayout = _ProjectLayout.fromRepositoryRoot(checkRoot);
    await checkLayout.validate();
    await _generateSwaggerSources(checkLayout);
    await _runDart(const [
      'run',
      'build_runner',
      'build',
    ], workingDirectory: checkLayout.clientRoot);
    await _formatGeneratedApi(checkLayout);
    await _validateGeneratedOutput(checkLayout.generatedDirectory);

    final regenerated = await _snapshotManagedOutputs(checkLayout);
    final drift = _compareSnapshots(committed, regenerated);
    if (drift.isNotEmpty) {
      throw StateError(
        'Generated Dart outputs are stale or were edited by hand:\n'
        '${drift.map((item) => '  - $item').join('\n')}\n'
        'Run `dart run melos run api:generate` and commit the result.',
      );
    }
    stdout.writeln('Generated Dart outputs are current.');
  } finally {
    await _deleteMarkedCheckWorkspace(checkRoot);
  }
}

Future<void> _generateSwaggerSources(_ProjectLayout layout) async {
  await _resetGeneratedDirectory(layout.generatedDirectory);
  await GenProcessor(
    SWPConfig(
      schemaPath: layout.contractFile.path,
      outputDirectory: layout.generatedDirectory.path,
      name: 'ordinApi',
      rootClientName: 'OrdinApiClient',
      clientPostfix: 'Api',
      jsonSerializer: JsonSerializer.jsonSerializable,
      unknownEnumValue: true,
      markFilesAsGenerated: true,
      extrasParameterByDefault: true,
      addOpenApiMetadata: true,
    ),
  ).generateFiles();
  await File(
    path.join(layout.generatedDirectory.path, _generatedMarkerName),
  ).writeAsString(_generatedMarkerContent, flush: true);
}

Future<void> _formatGeneratedApi(_ProjectLayout layout) => _runDart([
  'format',
  layout.generatedDirectory.path,
], workingDirectory: layout.clientRoot);

Future<void> _copyCheckWorkspace(
  _ProjectLayout source,
  Directory destinationRoot,
) async {
  await _copyRequiredFile(
    File(path.join(source.repositoryRoot.path, 'pubspec.yaml')),
    File(path.join(destinationRoot.path, 'pubspec.yaml')),
  );
  await _copyRequiredFile(
    File(path.join(source.repositoryRoot.path, 'pubspec.lock')),
    File(path.join(destinationRoot.path, 'pubspec.lock')),
  );

  final rootBuildConfig = File(
    path.join(source.repositoryRoot.path, 'build.yaml'),
  );
  if (await rootBuildConfig.exists()) {
    await _copyRequiredFile(
      rootBuildConfig,
      File(path.join(destinationRoot.path, 'build.yaml')),
    );
  }

  await _copyDirectory(
    source.clientRoot,
    Directory(path.join(destinationRoot.path, 'apps', 'client')),
    excludedNames: const {
      '.dart_tool',
      'build',
      'android',
      'ios',
      'linux',
      'macos',
      'windows',
    },
  );
  await _copyRequiredFile(
    source.contractFile,
    File(
      path.join(
        destinationRoot.path,
        'contracts',
        'openapi',
        'ordin-api-v1.json',
      ),
    ),
  );

  final sourceDartTool = Directory(
    path.join(source.repositoryRoot.path, '.dart_tool'),
  );
  final destinationDartTool = Directory(
    path.join(destinationRoot.path, '.dart_tool'),
  );
  for (final relativePath in const [
    'package_config.json',
    'package_graph.json',
    'version',
    'pub/workspace_ref.json',
  ]) {
    await _copyRequiredFile(
      File(path.join(sourceDartTool.path, relativePath)),
      File(path.join(destinationDartTool.path, relativePath)),
    );
  }
}

Future<void> _copyDirectory(
  Directory source,
  Directory destination, {
  Set<String> excludedNames = const {},
}) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    final name = path.basename(entity.path);
    if (excludedNames.contains(name)) {
      continue;
    }
    final targetPath = path.join(destination.path, name);
    if (entity is File) {
      await _copyRequiredFile(entity, File(targetPath));
    } else if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is Link) {
      throw StateError(
        'Symlinks are unsupported in isolated codegen input: ${entity.path}',
      );
    }
  }
}

Future<void> _copyRequiredFile(File source, File destination) async {
  if (!await source.exists()) {
    throw StateError(
      'Required isolated codegen input is missing: ${source.path}',
    );
  }
  await destination.parent.create(recursive: true);
  await source.copy(destination.path);
}

Future<void> _cleanupStaleCheckWorkspaces() async {
  await for (final entity in Directory.systemTemp.list(followLinks: false)) {
    if (entity is! Directory ||
        !path.basename(entity.path).startsWith(_checkDirectoryPrefix)) {
      continue;
    }
    final marker = File(path.join(entity.path, _checkWorkspaceMarkerName));
    if (await marker.exists() &&
        await marker.readAsString() == _checkWorkspaceMarkerContent) {
      await _deleteMarkedCheckWorkspace(entity);
    }
  }
}

Future<void> _deleteMarkedCheckWorkspace(Directory directory) async {
  final expectedParent = path.normalize(Directory.systemTemp.absolute.path);
  final actual = path.normalize(directory.absolute.path);
  final marker = File(path.join(actual, _checkWorkspaceMarkerName));
  if (!path.equals(path.dirname(actual), expectedParent) ||
      !path.basename(actual).startsWith(_checkDirectoryPrefix) ||
      !await marker.exists() ||
      await marker.readAsString() != _checkWorkspaceMarkerContent) {
    throw StateError('Refusing to delete untrusted check workspace: $actual');
  }
  await directory.delete(recursive: true);
}

Future<Map<String, Object?>> _readAndValidateContract(File contractFile) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(await contractFile.readAsString());
  } on FormatException catch (error) {
    throw StateError('OpenAPI contract is not valid JSON: $error');
  }
  if (decoded is! Map<String, Object?>) {
    throw StateError('OpenAPI contract root must be an object.');
  }
  if (decoded['openapi'] != '3.1.0') {
    throw StateError('OpenAPI contract must use version 3.1.0.');
  }
  _rejectOpenApiDateFormat(decoded, r'$');

  final components = _object(decoded['components'], 'components');
  final securitySchemes = _object(
    components['securitySchemes'],
    'components.securitySchemes',
  );
  final accessToken = _object(
    securitySchemes['AccessToken'],
    'components.securitySchemes.AccessToken',
  );
  if (accessToken['type'] != 'http' || accessToken['scheme'] != 'bearer') {
    throw StateError('AccessToken must be an HTTP bearer security scheme.');
  }

  final schemas = _object(components['schemas'], 'components.schemas');
  for (final schemaEntry in schemas.entries) {
    final schema = _object(schemaEntry.value, 'schema ${schemaEntry.key}');
    final properties = schema['properties'];
    if (properties is! Map<String, Object?>) {
      continue;
    }
    for (final propertyEntry in properties.entries) {
      if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(propertyEntry.key)) {
        throw StateError(
          'JSON property must be lowerCamelCase: '
          '${schemaEntry.key}.${propertyEntry.key}',
        );
      }
      final property = _object(
        propertyEntry.value,
        '${schemaEntry.key}.${propertyEntry.key}',
      );
      _validateSupportedUnion(schemaEntry.key, propertyEntry.key, property);
      if (_isDateOnlyName(propertyEntry.key)) {
        _validateStrictDateString(schemaEntry.key, propertyEntry.key, property);
      }
    }
  }

  final paths = _object(decoded['paths'], 'paths');
  final operationIds = <String>{};
  for (final pathEntry in paths.entries) {
    for (final match in RegExp(r'{([^}]+)}').allMatches(pathEntry.key)) {
      final parameter = match.group(1)!;
      if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(parameter)) {
        throw StateError('Path parameter must be lowerCamelCase: $parameter');
      }
    }
    final pathItem = _object(pathEntry.value, 'path ${pathEntry.key}');
    for (final operationEntry in pathItem.entries) {
      if (!_httpMethods.contains(operationEntry.key)) {
        continue;
      }
      final operation = _object(
        operationEntry.value,
        '${operationEntry.key} ${pathEntry.key}',
      );
      final operationId = operation['operationId'];
      if (operationId is! String ||
          !RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(operationId)) {
        throw StateError(
          'Operation ID must be stable lowerCamelCase: '
          '${operationEntry.key} ${pathEntry.key}',
        );
      }
      if (!operationIds.add(operationId)) {
        throw StateError('Duplicate operation ID: $operationId');
      }
      _validateDateOnlyParameters(operation, operationId);
      _validateOperationSecurity(operation, operationId);
      _validateProblemResponses(operation, operationId);
    }
  }

  return decoded;
}

void _validateStrictDateString(
  String schemaName,
  String propertyName,
  Map<String, Object?> property,
) {
  final anyOf = property['anyOf'];
  if (anyOf == null) {
    if (property['type'] == 'string' &&
        property['pattern'] == _strictDatePattern) {
      return;
    }
    throw StateError(
      'Date-only value must be a strict YYYY-MM-DD string: '
      '$schemaName.$propertyName',
    );
  }
  if (anyOf is! List<Object?> || anyOf.length != 2) {
    throw StateError(
      'Nullable date-only value must use string-or-null anyOf: '
      '$schemaName.$propertyName',
    );
  }
  final branches = anyOf
      .map((branch) => _object(branch, '$schemaName.$propertyName.anyOf'))
      .toList();
  final dateBranches = branches.where(
    (branch) =>
        branch['type'] == 'string' && branch['pattern'] == _strictDatePattern,
  );
  final nullBranches = branches.where((branch) => branch['type'] == 'null');
  if (dateBranches.length != 1 || nullBranches.length != 1) {
    throw StateError(
      'Nullable date-only value must be strict YYYY-MM-DD string or null: '
      '$schemaName.$propertyName',
    );
  }
}

void _validateDateOnlyParameters(
  Map<String, Object?> operation,
  String operationId,
) {
  final parameters = operation['parameters'];
  if (parameters is! List<Object?>) {
    return;
  }
  for (final value in parameters) {
    final parameter = _object(value, '$operationId parameter');
    final name = parameter['name'];
    if (name is String && _isDateOnlyName(name)) {
      _validateStrictDateString(
        operationId,
        name,
        _object(parameter['schema'], '$operationId parameter $name schema'),
      );
    }
  }
}

bool _isDateOnlyName(String value) =>
    value == 'birthDate' || value == 'localDay' || value.endsWith('LocalDay');

void _rejectOpenApiDateFormat(Object? value, String location) {
  if (value is Map<String, Object?>) {
    if (value['format'] == 'date') {
      throw StateError(
        'OpenAPI format: date is unsupported at $location; '
        'use a strict YYYY-MM-DD pattern string.',
      );
    }
    for (final entry in value.entries) {
      _rejectOpenApiDateFormat(entry.value, '$location.${entry.key}');
    }
  } else if (value is List<Object?>) {
    for (var index = 0; index < value.length; index++) {
      _rejectOpenApiDateFormat(value[index], '$location[$index]');
    }
  }
}

void _validateSupportedUnion(
  String schemaName,
  String propertyName,
  Map<String, Object?> property,
) {
  final anyOf = property['anyOf'];
  if (anyOf is! List<Object?>) {
    return;
  }
  final nonNullBranches = anyOf.where((branch) {
    final item = _object(branch, '$schemaName.$propertyName.anyOf');
    return item['type'] != 'null';
  }).toList();
  if (nonNullBranches.length > 1) {
    throw StateError(
      'Unsupported multi-type anyOf would generate dynamic: '
      '$schemaName.$propertyName',
    );
  }
}

void _validateOperationSecurity(
  Map<String, Object?> operation,
  String operationId,
) {
  final security = operation['security'];
  if (_publicOperationIds.contains(operationId)) {
    if (security == null || (security is List<Object?> && security.isEmpty)) {
      return;
    }
    throw StateError('Public operation must not require auth: $operationId.');
  }

  if (security is! List<Object?> || security.length != 1) {
    throw StateError(
      'Protected operation must declare exactly one AccessToken requirement: '
      '$operationId.',
    );
  }
  final requirement = _object(security.single, '$operationId.security');
  final scopes = requirement['AccessToken'];
  if (requirement.length != 1 ||
      !requirement.containsKey('AccessToken') ||
      scopes is! List<Object?> ||
      scopes.isNotEmpty) {
    throw StateError(
      'Protected operation must require AccessToken with no scopes: '
      '$operationId.',
    );
  }
}

void _validateProblemResponses(
  Map<String, Object?> operation,
  String operationId,
) {
  final responses = _object(operation['responses'], '$operationId.responses');
  for (final responseEntry in responses.entries) {
    if (!RegExp(r'^[45][0-9][0-9]$').hasMatch(responseEntry.key)) {
      continue;
    }
    final response = _object(
      responseEntry.value,
      '$operationId response ${responseEntry.key}',
    );
    final content = _object(
      response['content'],
      '$operationId response ${responseEntry.key}.content',
    );
    final problem = _object(
      content['application/problem+json'],
      '$operationId response ${responseEntry.key} application/problem+json',
    );
    final schema = _object(problem['schema'], '$operationId problem schema');
    if (schema[r'$ref'] != '#/components/schemas/ProblemDetails') {
      throw StateError(
        '$operationId response ${responseEntry.key} must reference '
        'ProblemDetails as application/problem+json.',
      );
    }
  }
}

Map<String, Object?> _object(Object? value, String description) {
  if (value case final Map<String, Object?> object) {
    return object;
  }
  throw StateError('$description must be an object.');
}

Future<void> _resetGeneratedDirectory(Directory generatedDirectory) async {
  if (await generatedDirectory.exists()) {
    final entries = await generatedDirectory.list().toList();
    final marker = File(
      path.join(generatedDirectory.path, _generatedMarkerName),
    );
    if (entries.isNotEmpty &&
        (!await marker.exists() ||
            await marker.readAsString() != _generatedMarkerContent)) {
      throw StateError(
        'Refusing to delete an unmarked directory: '
        '${generatedDirectory.path}',
      );
    }
    await generatedDirectory.delete(recursive: true);
  }
  await generatedDirectory.create(recursive: true);
}

Future<void> _runDart(
  List<String> arguments, {
  required Directory workingDirectory,
}) async {
  stdout.writeln('> dart ${arguments.join(' ')}');
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      arguments,
      'Command exited with code $result.',
      result,
    );
  }
}

Future<void> _validateGeneratedOutput(Directory generatedDirectory) async {
  final dartFiles = await generatedDirectory
      .list(recursive: true)
      .where((entry) => entry is File && entry.path.endsWith('.dart'))
      .cast<File>()
      .toList();
  if (dartFiles.isEmpty) {
    throw StateError('Generator did not produce Dart files.');
  }
  for (final file in dartFiles) {
    final source = await file.readAsString();
    if (RegExp(r'\bfinal dynamic\b|\bFuture<dynamic>\b').hasMatch(source)) {
      throw StateError(
        'Unexpected dynamic API type generated in '
        '${path.relative(file.path, from: generatedDirectory.path)}.',
      );
    }
    if (source.contains('DateOnlyJsonConverter')) {
      throw StateError(
        'Unexpected DateOnlyJsonConverter generated in '
        '${path.relative(file.path, from: generatedDirectory.path)}.',
      );
    }
  }
}

Future<Map<String, Uint8List>> _snapshotManagedOutputs(
  _ProjectLayout layout,
) async {
  final files = <File>[];
  if (await layout.generatedDirectory.exists()) {
    files.addAll(
      await layout.generatedDirectory
          .list(recursive: true)
          .where((entry) => entry is File)
          .cast<File>()
          .toList(),
    );
  }

  for (final sourceRootName in const ['lib', 'test']) {
    final sourceRoot = Directory(
      path.join(layout.clientRoot.path, sourceRootName),
    );
    if (!await sourceRoot.exists()) {
      continue;
    }
    await for (final entry in sourceRoot.list(recursive: true)) {
      if (entry is! File ||
          path.isWithin(layout.generatedDirectory.path, entry.path) ||
          !entry.path.endsWith('.dart')) {
        continue;
      }
      final name = path.basename(entry.path);
      if (name.endsWith('.g.dart') ||
          name.endsWith('.freezed.dart') ||
          name.endsWith('.mapper.dart') ||
          name.endsWith('.drift.dart')) {
        files.add(entry);
        continue;
      }
      final source = await entry.readAsString();
      if (source.contains('// GENERATED CODE - DO NOT MODIFY BY HAND')) {
        files.add(entry);
      }
    }
  }

  files.sort((left, right) => left.path.compareTo(right.path));

  return {
    for (final file in files)
      path
          .relative(file.path, from: layout.clientRoot.path)
          .replaceAll(path.separator, '/'): await file
          .readAsBytes(),
  };
}

List<String> _compareSnapshots(
  Map<String, Uint8List> before,
  Map<String, Uint8List> after,
) {
  final paths = {...before.keys, ...after.keys}.toList()..sort();
  return [
    for (final filePath in paths)
      if (!before.containsKey(filePath))
        'added $filePath'
      else if (!after.containsKey(filePath))
        'removed $filePath'
      else if (!_bytesEqual(before[filePath]!, after[filePath]!))
        'changed $filePath',
  ];
}

bool _bytesEqual(Uint8List left, Uint8List right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

final class UsageException implements Exception {
  const UsageException(this.message);

  final String message;
}
