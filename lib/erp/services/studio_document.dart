import 'dart:convert';

/// Versioned, data-only design document. Imported JSON never contains executable code.
class StudioDocument {
  StudioDocument({
    required this.id,
    required this.name,
    required this.nodes,
    this.schemaVersion = 2,
    this.designKind = 'screen',
    this.updatedAt,
    this.remoteId,
    this.remoteRevision = 0,
    Map<String, dynamic>? bindings,
    Map<String, dynamic>? settings,
  })  : bindings = Map<String, dynamic>.from(bindings ?? const {}),
        settings = Map<String, dynamic>.from(settings ?? const {});

  final String id;
  final String name;
  final int schemaVersion;
  final String designKind;
  final DateTime? updatedAt;
  final String? remoteId;
  final int remoteRevision;
  final List<StudioNode> nodes;
  final Map<String, dynamic> bindings;
  final Map<String, dynamic> settings;

  factory StudioDocument.create(String name, {String designKind = 'screen'}) =>
      StudioDocument(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        designKind: designKind,
        nodes: [
          StudioNode(id: 'title', type: 'text', props: {
            'text': name, 'size': 22, 'bold': true, 'width': 'fill'
          }),
          StudioNode(id: 'intro', type: 'text', props: {
            'text': 'ابدأ بإضافة مكونات التصميم من مكتبة العناصر.'
          }),
        ],
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': 2,
        'id': id,
        'name': name,
        'designKind': designKind,
        'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'remoteId': remoteId,
        'remoteRevision': remoteRevision,
        'bindings': bindings,
        'settings': settings,
        'nodes': nodes.map((e) => e.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory StudioDocument.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != 1 && version != 2) {
      throw FormatException('إصدار مخطط التصميم غير مدعوم: $version');
    }
    final rawNodes = json['nodes'];
    if (rawNodes is! List || rawNodes.length > 500) {
      throw const FormatException('قائمة المكونات غير صالحة أو تجاوزت الحد المسموح.');
    }
    final parsedNodes = rawNodes.map((e) {
      if (e is! Map) throw const FormatException('تعريف مكون غير صالح.');
      return StudioNode.fromJson(Map<String, dynamic>.from(e));
    }).toList();
    final ids = parsedNodes.map((e) => e.id).toSet();
    if (ids.length != parsedNodes.length) {
      throw const FormatException('معرّفات المكونات يجب أن تكون فريدة.');
    }
    final rawBindings = json['bindings'];
    final rawSettings = json['settings'];
    if (rawBindings != null && rawBindings is! Map) {
      throw const FormatException('تعريفات الربط غير صالحة.');
    }
    if (rawSettings != null && rawSettings is! Map) {
      throw const FormatException('إعدادات التصميم غير صالحة.');
    }
    final kind = json['designKind']?.toString() ?? 'screen';
    const kinds = {'screen', 'report', 'icon', 'tree', 'table', 'grid', 'form', 'component'};
    if (!kinds.contains(kind)) throw FormatException('نوع التصميم غير مسجل: $kind');
    return StudioDocument(
      id: _requiredString(json['id'], 'id'),
      name: _requiredString(json['name'], 'name'),
      schemaVersion: 2,
      designKind: kind,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      remoteId: json['remoteId'] is String ? json['remoteId'] as String : null,
      remoteRevision: json['remoteRevision'] is int ? json['remoteRevision'] as int : 0,
      bindings: rawBindings == null ? const {} : Map<String, dynamic>.from(rawBindings as Map),
      settings: rawSettings == null ? const {} : Map<String, dynamic>.from(rawSettings as Map),
      nodes: parsedNodes,
    );
  }

  static String _requiredString(dynamic value, String key) {
    if (value is! String || value.trim().isEmpty || value.length > 160) {
      throw FormatException('قيمة $key غير صالحة.');
    }
    return value;
  }

  StudioDocument copyWith({
    String? name,
    String? designKind,
    List<StudioNode>? nodes,
    String? remoteId,
    int? remoteRevision,
    Map<String, dynamic>? bindings,
    Map<String, dynamic>? settings,
  }) =>
      StudioDocument(
        id: id,
        name: name ?? this.name,
        schemaVersion: 2,
        designKind: designKind ?? this.designKind,
        nodes: nodes ?? this.nodes,
        updatedAt: DateTime.now(),
        remoteId: remoteId ?? this.remoteId,
        remoteRevision: remoteRevision ?? this.remoteRevision,
        bindings: bindings ?? this.bindings,
        settings: settings ?? this.settings,
      );
}

class StudioNode {
  StudioNode({
    required this.id,
    required this.type,
    Map<String, dynamic>? props,
    this.parentId,
    this.groupId,
    this.hidden = false,
    this.locked = false,
  }) : props = Map<String, dynamic>.from(props ?? const {});

  final String id;
  final String type;
  final Map<String, dynamic> props;
  final String? parentId;
  final String? groupId;
  final bool hidden;
  final bool locked;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'props': props,
        'parentId': parentId,
        'groupId': groupId,
        'hidden': hidden,
        'locked': locked,
      };

  factory StudioNode.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final props = json['props'];
    if (id is! String || id.isEmpty || id.length > 100 ||
        type is! String || type.length > 40 || props is! Map || props.length > 40) {
      throw const FormatException('خصائص المكون غير صالحة.');
    }
    const allowed = {
      'text', 'button', 'field', 'card', 'divider', 'spacer', 'grid',
      'tree', 'table', 'icon', 'image', 'chart', 'tabs', 'form',
      'list', 'badge', 'progress', 'stat', 'container', 'filter'
    };
    if (!allowed.contains(type)) throw FormatException('نوع مكون غير مسجل: $type');
    final parent = json['parentId'];
    final group = json['groupId'];
    if (parent != null && (parent is! String || parent.length > 100)) {
      throw const FormatException('مرجع الحاوية غير صالح.');
    }
    if (group != null && (group is! String || group.length > 100)) {
      throw const FormatException('مرجع المجموعة غير صالح.');
    }
    _validateJsonValue(props);
    return StudioNode(
      id: id,
      type: type,
      props: Map<String, dynamic>.from(props),
      parentId: parent as String?,
      groupId: group as String?,
      hidden: json['hidden'] == true,
      locked: json['locked'] == true,
    );
  }

  StudioNode copyWith({
    Map<String, dynamic>? props,
    String? parentId,
    String? groupId,
    bool? hidden,
    bool? locked,
    bool clearGroup = false,
  }) =>
      StudioNode(
        id: id,
        type: type,
        props: props ?? this.props,
        parentId: parentId ?? this.parentId,
        groupId: clearGroup ? null : groupId ?? this.groupId,
        hidden: hidden ?? this.hidden,
        locked: locked ?? this.locked,
      );
}

void _validateJsonValue(dynamic value, [int depth = 0]) {
  if (depth > 8) throw const FormatException('تداخل خصائص التصميم أعمق من المسموح.');
  if (value == null || value is bool || value is num) return;
  if (value is String) {
    if (value.length > 4000) throw const FormatException('إحدى قيم التصميم أطول من المسموح.');
    return;
  }
  if (value is List) {
    if (value.length > 500) throw const FormatException('قائمة داخل التصميم أكبر من المسموح.');
    for (final item in value) {
      _validateJsonValue(item, depth + 1);
    }
    return;
  }
  if (value is Map) {
    if (value.length > 80) throw const FormatException('خصائص التصميم أكثر من المسموح.');
    for (final entry in value.entries) {
      if (entry.key is! String) throw const FormatException('مفتاح خاصية غير صالح.');
      _validateJsonValue(entry.value, depth + 1);
    }
    return;
  }
  throw const FormatException('نوع بيانات غير مسموح داخل التصميم.');
}
