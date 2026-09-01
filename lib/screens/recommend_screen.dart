import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> with SingleTickerProviderStateMixin {
  final AppState _state = AppState();
  late TabController _tabController;
  bool _sendMode = false;
  String? _targetWardrobeId;
  final Set<String> _selectedClotheIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Wardrobe> get _sharedWardrobes =>
      _state.wardrobes.where((w) => w.visibility == 'shared' && w.owner != _state.username).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('穿搭推荐', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFB8860B),
          unselectedLabelColor: Colors.black45,
          indicatorColor: const Color(0xFFB8860B),
          tabs: [
            Tab(text: '收到的推荐 (${_state.receivedRecommendations.length})'),
            Tab(text: '发出的推荐 (${_state.sentRecommendations.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_sendMode ? Icons.close : Icons.send),
            onPressed: _sharedWardrobes.isEmpty ? null : () => setState(() => _sendMode = !_sendMode),
            tooltip: '发送推荐',
          ),
        ],
      ),
      body: _sendMode ? _buildSendMode() : TabBarView(controller: _tabController, children: [
        _buildRecommendationList(_state.receivedRecommendations, true),
        _buildRecommendationList(_state.sentRecommendations, false),
      ]),
    );
  }

  Widget _buildSendMode() {
    if (_targetWardrobeId == null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFB8860B).withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB8860B)),
                SizedBox(width: 8),
                Expanded(child: Text('选择一个共享衣柜，从中挑选衣物推荐给对方', style: TextStyle(fontSize: 13))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _sharedWardrobes.length,
              itemBuilder: (_, i) {
                final w = _sharedWardrobes[i];
                final count = _state.wardrobeData[w.id]?.clothes.length ?? 0;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFB8860B), child: Icon(Icons.checkroom, color: Colors.white)),
                    title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${w.owner} · $count 件衣物'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _targetWardrobeId = w.id),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    final targetData = _state.wardrobeData[_targetWardrobeId];
    final clothes = targetData?.clothes ?? [];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFB8860B).withOpacity(0.1),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() { _targetWardrobeId = null; _selectedClotheIds.clear(); })),
              Expanded(child: Text('从「${_state.wardrobes.firstWhere((w) => w.id == _targetWardrobeId).name}」选衣（${_selectedClotheIds.length}件）', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ElevatedButton(
                onPressed: _selectedClotheIds.isEmpty ? null : _showRecommendMessageDialog,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)),
                child: const Text('发送'),
              ),
            ],
          ),
        ),
        Expanded(
          child: clothes.isEmpty
              ? const Center(child: Text('这个衣柜还没有衣物', style: TextStyle(color: Colors.black45)))
              : GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: clothes.length,
                  itemBuilder: (_, i) {
                    final c = clothes[i];
                    final selected = _selectedClotheIds.contains(c.id);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) _selectedClotheIds.remove(c.id);
                        else _selectedClotheIds.add(c.id);
                      }),
                      child: Stack(
                        children: [
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Expanded(child: c.imageUrl.isNotEmpty ? CachedNetworkImage(imageUrl: c.imageUrl, fit: BoxFit.cover, width: double.infinity) : Container(color: const Color(0xFFF0E8D8), width: double.infinity)),
                                Padding(padding: const EdgeInsets.all(4), child: Text(c.name, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          if (selected) Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFFB8860B), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14))),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showRecommendMessageDialog() {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('写一句推荐语'),
        content: TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: '为什么推荐这套？'), maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              await _state.sendRecommendation(_targetWardrobeId!, _selectedClotheIds.toList(), msgCtrl.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {
                  _sendMode = false;
                  _targetWardrobeId = null;
                  _selectedClotheIds.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('推荐已发送')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)),
            child: const Text('发送推荐'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationList(List<Recommendation> recs, bool isReceived) {
    if (recs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isReceived ? Icons.inbox : Icons.send, size: 60, color: const Color(0xFFCCC0A8)),
            const SizedBox(height: 12),
            Text(isReceived ? '还没有收到推荐' : '还没有发出推荐', style: const TextStyle(color: Colors.black45)),
            if (isReceived && _sharedWardrobes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(onPressed: () => setState(() => _sendMode = true), icon: const Icon(Icons.send), label: const Text('去给TA推荐')),
              ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: recs.length,
      itemBuilder: (_, i) {
        final rec = recs[i];
        final targetW = _state.wardrobes.cast<Wardrobe?>().firstWhere((w) => w?.id == rec.toWardrobeId, orElse: () => null);
        final clothes = rec.clotheIds.map((id) => _state.findClothe(rec.toWardrobeId, id)).whereType<Clothe>().toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: const Color(0xFFB8860B).withOpacity(0.15), child: Text(rec.fromUser.substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFFB8860B), fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${rec.fromUser} 推荐给 ${targetW?.name ?? ""}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
                    _buildStatusBadge(rec.status),
                  ],
                ),
                if (rec.message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFAF6F0), borderRadius: BorderRadius.circular(8)), child: Text(rec.message, style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: clothes.length,
                    itemBuilder: (_, j) {
                      final c = clothes[j];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: c.imageUrl.isNotEmpty ? CachedNetworkImage(imageUrl: c.imageUrl, width: 56, height: 56, fit: BoxFit.cover) : Container(width: 56, height: 56, color: const Color(0xFFF0E8D8), child: const Icon(Icons.checkroom, color: Colors.white30, size: 20))),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(DateFormat('yyyy-MM-dd HH:mm').format(rec.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black38)),
                if (isReceived && rec.status == 'pending') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _state.respondRecommendation(rec.id, 'ignored'), style: OutlinedButton.styleFrom(foregroundColor: Colors.black45), child: const Text('忽略'))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(onPressed: () => _acceptRecommendation(rec), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)), child: const Text('采纳为穿搭'))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'pending':
        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('待处理', style: TextStyle(fontSize: 11, color: Colors.orange)));
      case 'accepted':
        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('已采纳', style: TextStyle(fontSize: 11, color: Colors.green)));
      case 'ignored':
        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Text('已忽略', style: TextStyle(fontSize: 11, color: Colors.grey)));
      default:
        return const SizedBox.shrink();
    }
  }

  void _acceptRecommendation(Recommendation rec) async {
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('采纳为穿搭'),
        content: TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: '穿搭日期 (yyyy-MM-dd)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              await _state.respondRecommendation(rec.id, 'accepted', outfitDate: dateCtrl.text);
              // 同时添加穿搭记录
              await _state.addOutfit(dateCtrl.text, rec.clotheIds, '来自 ${rec.fromUser} 的推荐');
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已采纳并添加到穿搭')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB8860B)),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
