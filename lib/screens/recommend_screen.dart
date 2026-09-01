import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class RecommendScreen extends StatefulWidget {
  final String? preselectedClotheId; // 从衣物详情页推荐时预选中
  const RecommendScreen({super.key, this.preselectedClotheId});

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
    // 如果有预选中的衣物，自动进入发送模式
    if (widget.preselectedClotheId != null) {
      _selectedClotheIds.add(widget.preselectedClotheId!);
      _sendMode = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('穿搭推荐', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5C2E0A),
          unselectedLabelColor: Colors.black45,
          indicatorColor: const Color(0xFF5C2E0A),
          tabs: [
            Tab(text: '收到 (${_state.receivedRecommendations.length})'),
            Tab(text: '发出 (${_state.sentRecommendations.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_sendMode ? Icons.close : Icons.send),
            onPressed: _state.currentClothes.isEmpty ? null : () => setState(() => _sendMode = !_sendMode),
            tooltip: _sendMode ? '取消' : '推荐衣物',
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
    // 第一步：选择目标衣柜
    if (_targetWardrobeId == null) {
      final targets = _state.recommendableWardrobes;
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF5C2E0A).withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF5C2E0A)),
                SizedBox(width: 8),
                Expanded(child: Text('选择要推荐给哪个衣柜（共享衣柜）', style: TextStyle(fontSize: 13))),
              ],
            ),
          ),
          if (targets.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group_off, size: 60, color: Color(0xFFCCC0A8)),
                    const SizedBox(height: 12),
                    const Text('还没有可推荐的共享衣柜', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    const Text('让对方创建一个共享衣柜，或把你的衣柜设为共享', style: TextStyle(fontSize: 12, color: Colors.black38), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: targets.length,
                itemBuilder: (_, i) {
                  final w = targets[i];
                  final count = _state.wardrobeData[w.id]?.clothes.length ?? 0;
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFF5C2E0A), child: Icon(Icons.checkroom, color: Colors.white)),
                      title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text('${w.owner} · $count 件衣物${w.description.isNotEmpty ? "\n${w.description}" : ""}'),
                      isThreeLine: w.description.isNotEmpty,
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

    // 第二步：从自己的衣柜选衣服
    final targetW = _state.wardrobes.firstWhere((w) => w.id == _targetWardrobeId);
    final myClothes = _state.currentClothes;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF5C2E0A).withOpacity(0.1),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _targetWardrobeId = null;
                }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('推荐给「${targetW.name}」', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('从你的「${_state.currentWardrobe?.name ?? ''}」选 ${_selectedClotheIds.length} 件衣物', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _selectedClotheIds.isEmpty ? null : _showRecommendMessageDialog,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C2E0A)),
                child: const Text('发送'),
              ),
            ],
          ),
        ),
        if (myClothes.isEmpty)
          const Expanded(child: Center(child: Text('你的衣柜还没有衣物', style: TextStyle(color: Colors.black45))))
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: myClothes.length,
              itemBuilder: (_, i) {
                final c = myClothes[i];
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
                          children: [
                            Expanded(
                              child: c.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: c.imageUrl, fit: BoxFit.cover, width: double.infinity)
                                  : Container(color: const Color(0xFFF0E8D8), width: double.infinity, child: const Center(child: Icon(Icons.checkroom, color: Colors.white30))),
                            ),
                            Padding(padding: const EdgeInsets.all(4), child: Text(c.name, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                      if (selected)
                        Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Color(0xFF5C2E0A), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 14))),
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
        content: TextField(controller: msgCtrl, decoration: const InputDecoration(labelText: '为什么推荐这套？（可选）', hintText: '比如：这件很适合你最近的风格~'), maxLines: 3, autofocus: true),
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
                _tabController.animateTo(1); // 切换到"发出"tab
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('推荐已发送，对方会收到通知')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C2E0A)),
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
            if (isReceived) ...[
              const SizedBox(height: 8),
              const Text('点击右上角发送按钮，给TA推荐衣物', style: TextStyle(fontSize: 12, color: Colors.black38)),
              const SizedBox(height: 12),
              TextButton.icon(onPressed: () => setState(() => _sendMode = true), icon: const Icon(Icons.send), label: const Text('去推荐')),
            ],
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
        // 推荐的衣物来自发送者的衣柜
        final fromWardrobe = _state.wardrobes.cast<Wardrobe?>().firstWhere((w) => w?.owner == rec.fromUser, orElse: () => null);
        final clothes = rec.clotheIds.map((id) => _state.findClothe(fromWardrobe?.id ?? '', id)).whereType<Clothe>().toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: const Color(0xFF5C2E0A).withOpacity(0.15), child: Text(rec.fromUser.substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFF5C2E0A), fontSize: 12, fontWeight: FontWeight.bold))),
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
                if (clothes.isNotEmpty)
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: clothes.length,
                      itemBuilder: (_, j) {
                        final c = clothes[j];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            children: [
                              ClipRRect(borderRadius: BorderRadius.circular(8), child: c.imageUrl.isNotEmpty ? CachedNetworkImage(imageUrl: c.imageUrl, width: 56, height: 56, fit: BoxFit.cover) : Container(width: 56, height: 56, color: const Color(0xFFF0E8D8), child: const Icon(Icons.checkroom, color: Colors.white30, size: 20))),
                              const SizedBox(height: 2),
                              SizedBox(width: 56, child: Text(c.name, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                            ],
                          ),
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
                      Expanded(child: ElevatedButton(onPressed: () => _acceptRecommendation(rec), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C2E0A)), child: const Text('采纳为穿搭'))),
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
              // 同时添加穿搭记录到当前衣柜
              await _state.addOutfit(dateCtrl.text, rec.clotheIds, '来自 ${rec.fromUser} 的推荐');
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已采纳并添加到穿搭')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C2E0A)),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
