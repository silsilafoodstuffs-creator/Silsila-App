import 'dart:convert';

/// Versioned, data-only document format consumed by the Studio renderer.
class StudioDocument {
  StudioDocument({
    required this.id,
    required this.name,
    required this.nodes,
    this.schemaVersion = 1,
    this.updatedAt,
    this.remoteId,
    this.remoteRevision = 0,
  });

  final String id;
  final String name;
  final int schemaVersion;
  final DateTime? updatedAt;
  final String? remoteId;
  final int remoteRevision;
  final List<StudioNode> nodes;

  factory StudioDocument.create(String name) => StudioDocument(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        nodes: [
          StudioNode(id: 'title', type: 'text', props: {'text': name, 'size': 22, 'bold': true}),
          StudioNode(id: 'intro', type: 'text', props: {'text': 'ابدأ بإضافة مكونات الشاشة من مكتبة العناصر.'}),
        ],
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'remoteId': remoteId,
        'remoteRevision': remoteRevision,
        'nodes': nodes.map((e) => e.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory StudioDocument.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw FormatException('إصدار مخطط التصميم غير مدعوم: ${json['schemaVersion']}');
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
    return StudioDocument(
      id: _requiredString(json['id'], 'id'),
      name: _requiredString(json['name'], 'name'),
      schemaVersion: 1,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      remoteId: json['remoteId'] is String ? json['remoteId'] as String : null,
      remoteRevision: json['remoteRevision'] is int ? json['remoteRevision'] as int : 0,
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
    List<StudioNode>? nodes,
    String? remoteId,
    int? remoteRevision,
  }) =>
      StudioDocument(
        id: id,
        name: name ?? this.name,
        schemaVersion: schemaVersion,
        nodes: nodes ?? this.nodes,
        updatedAt: DateTime.now(),
        remoteId: remoteId ?? this.remoteId,
        remoteRevision: remoteRevision ?? this.remoteRevision,
      );
}

class StudioNode {
  StudioNode({required this.id, required this.type, Map<String, dynamic>? props})
      : props = Map<String, dynamic>.from(props ?? const {});

  final String id;
  final String type;
  final Map<String, dynamic> props;

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'props': props};

  factory StudioNode.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final props = json['props'];
    if (id is! String || id.isEmpty || id.length > 100 ||
        type is! String || type.length > 40 || props is! Map || props.length > 40) {
      throw const FormatException('خصائص المكون غير صالحة.');
    }
    const allowed = {'text', 'button', 'field', 'card', 'divider', 'spacer', 'grid', 'tree', 'table'};
    if (!allowed.contains(type)) throw FormatException('نوع مكون غير مسجل: $type');
    return StudioNode(id: id, type: type, props: Map<String, dynamic>.from(props));
  }

  StudioNode copyWith({Map<String, dynamic>? props}) =>
      StudioNode(id: id, type: type, props: props ?? this.props);
}
