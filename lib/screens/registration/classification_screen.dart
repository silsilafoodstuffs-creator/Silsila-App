import 'package:flutter/material.dart';

const Color silsilaPurple = Color(0xFF3E007D);
const Color silsilaOrange = Color(0xFFFFA015);
const Color silsilaPink = Color(0xFFFF27C3);

class SilsilaClassificationScreen extends StatefulWidget {
  final String title;
  final String description;
  final List<String> choices;
  final IconData icon;
  final String? initialSelection;

  const SilsilaClassificationScreen({
    super.key,
    required this.title,
    required this.description,
    required this.choices,
    this.icon = Icons.category_rounded,
    this.initialSelection,
  });

  @override
  State<SilsilaClassificationScreen> createState() =>
      _SilsilaClassificationScreenState();
}

class _SilsilaClassificationScreenState
    extends State<SilsilaClassificationScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String? _selected;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialSelection;
    if (initial != null && widget.choices.contains(initial)) {
      _selected = initial;
    }
  }

  List<String> get _filteredChoices {
    final query = _searchText.trim().toLowerCase();

    if (query.isEmpty) return widget.choices;

    return widget.choices
        .where((choice) => choice.toLowerCase().contains(query))
        .toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchText = '');
  }

  void _confirmSelection() {
    final selected = _selected;
    if (selected == null || !widget.choices.contains(selected)) return;

    Navigator.of(context).pop<String>(selected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredChoices = _filteredChoices;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6FB),
        appBar: AppBar(
          backgroundColor: silsilaPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            widget.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                decoration: const BoxDecoration(
                  color: silsilaPurple,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        widget.icon,
                        color: silsilaPurple,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'عدد الخيارات: ${widget.choices.length}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() => _searchText = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث عن التصنيف...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: silsilaPurple,
                    ),
                    suffixIcon: _searchText.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Color(0xFFE8E2EF),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: silsilaPurple,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filteredChoices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: silsilaPurple,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'لا توجد تصنيفات مطابقة للبحث',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_searchText.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _clearSearch,
                                  child: const Text('مسح البحث'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filteredChoices.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final choice = filteredChoices[index];
                          final isSelected = choice == _selected;

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() => _selected = choice);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? silsilaOrange
                                        : const Color(0xFFE8E2EF),
                                    width: isSelected ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      color: isSelected
                                          ? silsilaOrange
                                          : Colors.grey.shade400,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        choice,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: silsilaPurple,
                                        ),
                                      ),
                                    ),
                                    Radio<String>(
                                      value: choice,
                                      groupValue: _selected,
                                      activeColor: silsilaPurple,
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _selected = value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _selected == null ? null : _confirmSelection,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'اعتماد التصنيف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: silsilaPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
