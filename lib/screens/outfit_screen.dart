import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class OutfitScreen extends StatefulWidget {
  const OutfitScreen({super.key});

  @override
  State<OutfitScreen> createState() => _OutfitScreenState();
}

class _OutfitScreenState extends State<OutfitScreen> {
  final AppState _state = AppState();
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedClotheIds = {};
  bool _selectMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('穿搭日历', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_state.currentWardrobe != null && _state.currentWardrobe!.owner == _state.username)
            IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.add_circle_outline),
              onPressed: () => setState(() {
                _selectMode = !_selectMode;
                _selectedClotheIds.clear();
              }),
              tooltip: _selectMode ? '取消' : '记录穿搭',
            ),
        ],
      ),
      body: _state.currentWardrobe == null
          ? const Center(child: Text('请先选择或创建衣柜', style: TextStyle(color: Colors.black45)))
          : Column(
              children: [
                _buildCalendar(),
                Expanded(
                  child: _selectMode ? _buildClotheSelector() : _buildOutfitList(),
                ),
              ],
            ),
    );
  }

  Widget _buildCalendar() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    final outfitsByDate = <String, List<Outfit>>{};
    for (final o in _state.currentOutfits) {
      outfitsByDate.putIfAbsent(o.date, () => []).add(o);
    }

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDate = DateTime(year, month - 1)),
                ),
                Text(DateFormat('yyyy年 M月').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedDate = DateTime(year, month + 1)),
                ),
              ],
            ),
            Row(
              children: ['日', '一', '二', '三', '四', '五', '六']
                  .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 12, color: Colors.black45)))))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (_, i) {
                if (i < startWeekday) return const SizedBox.shrink();
                final day = i - startWeekday + 1;
                final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
                final hasOutfit = outfitsByDate.containsKey(dateStr);
                final isSelected = DateFormat('yyyy-MM-dd').format(_selectedDate) == dateStr;
                final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == dateStr;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = DateTime(year, month, day)),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFB8860B) : (isToday ? const Color(0xFFB8860B).withOpacity(0.15) : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day', style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : Colors.black87, fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal)),
                          if (hasOutfit) Container(width: 4, height: 4, decoration: BoxDecoration(color: isSelected ? Colors.white : const Color(0xFFB8860B), borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitList() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dayOutfits = _state.currentOutfits.where((o) => o.date == dateStr).toList();
    if (dayOutfits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 60, color: Color(0xFFCCC0A8)),
            const SizedBox(height: 12),
            Text(DateFormat('M月d日').format(_selectedDate), style: const TextStyle(fontSize: 16, color: Colors.black54)),
            const Text('这天还没有穿搭记录', style: TextStyle(color: Colors.black45)),
            if (_state.currentWardrobe!.owner == _state.username)
              TextButton.icon(
                onPressed: () => setState(() => _selectMode = true),
                icon: const Icon(Icons.add),
                label: const Text('记录今天的穿搭'),
              ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: dayOutfits.length,
      itemBuilder: (_, i) {
        final outfit = dayOutfits[i];
        final clothes = outfit.clotheIds.map((id) => _state.findClothe(_state.currentWardrobeId!, id)).whereType<Clothe>().toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (outfit.note.isNotEmpty) Text(outfit.note, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: clothes.length,
                    itemBuilder: (_, j) {
                      final c = clothes[j];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: c.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: c.imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                                  : Container(width: 60, height: 60, color: const Color(0xFFF0E8D8), child: const Icon(Icons.checkroom, color: Colors.white30)),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(width: 60, child: Text(c.name, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClotheSelector() {
    final clothes = _state.currentClothes;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFB8860B).withOpacity(0.1),
          child: Row(
            children: [
              Expanded(child: Text('为 ${DateFormat('M月d日').format(_selectedDate)} 选择衣物（${_selectedClotheIds.length}件）', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ElevatedButton(
                onPressed: _selectedClotheIds.isEmpty ? null : () => _showOutfitNoteDialog(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)),
                child: const Text('确认'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: clothes.length,
            itemBuilder: (_, i) {
              final c = clothes[i];
              final selected = _selectedClotheIds.contains(c.id);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedClotheIds.remove(c.id);
                  } else {
                    _selectedClotheIds.add(c.id);
                  }
                }),
                child: Stack(
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: c.imageUrl.isNotEmpty
                                ? CachedNetworkImage(imageUrl: c.imageUrl, fit: BoxFit.cover)
                                : Container(color: const Color(0xFFF0E8D8)),
                          ),
                          Padding(padding: const EdgeInsets.all(4), child: Text(c.name, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    if (selected)
                      Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFFB8860B), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showOutfitNoteDialog() {
    final noteCtrl = TextEditingController();
    bool submitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('穿搭备注'),
        content: TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: '今天的穿搭心得（可选）'), maxLines: 2),
        actions: [
          TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: submitting
                ? null
                : () async {
                    setState(() => submitting = true);
                    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
                    await _state.addOutfit(dateStr, _selectedClotheIds.toList(), noteCtrl.text.trim());
                    if (mounted) {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectMode = false;
                        _selectedClotheIds.clear();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('穿搭已记录')));
                    }
                  },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)),
            child: submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('保存'),
          ),
        ],
      ),
    );
  }
}
