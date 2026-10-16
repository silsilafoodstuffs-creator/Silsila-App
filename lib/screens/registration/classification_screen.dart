
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
  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';
  String? _selected;

  @override
  void initState() {
    super.initState();

    if (widget.initialSelection != null &&
        widget.choices.contains(widget.initialSelection)) {
      _selected = widget.initialSelection;
    }
  }

  List<String> get _filteredChoices {
    final query = _searchText.trim().toLowerCase();

    if (query.isEmpty) return widget.choices;

    return widget.choices
        .where((choice) => choice.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              fontFamily: 'Tajawal',
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                      radius: 29,
                      backgroundColor: Colors.white,
                      child: Icon(
                        widget.icon,
                        color: silsilaPurple,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: TextField(
                  controller: _searchController,
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
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchText = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _filteredChoices.isEmpty
                    ? const Center(
                        child: Text('لا توجد تصنيفات مطابقة للبحث'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filteredChoices.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final choice = _filteredChoices[index];
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
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? silsilaOrange
                                        : const Color(0xFFE8E2EF),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        choice,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: silsilaPurple,
                                          fontFamily: 'Tajawal',
                                        ),
                                      ),
                                    ),
                                    Radio<String>(
                                      value: choice,
                                      groupValue: _selected,
                                      activeColor: silsilaPurple,
                                      onChanged: (value) {
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
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.pop(context, _selected),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'اعتماد التصنيف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: silsilaPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
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
