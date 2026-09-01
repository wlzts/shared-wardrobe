import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_state.dart';
import '../models/models.dart';
import 'recommend_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final AppState _state = AppState();
  String _search = '';
  String _category = '全部';
  final ImagePicker _picker = ImagePicker();
  bool _isRefreshing = false;

  static const categories = ['全部', '上衣', '下装', '外套', '鞋子', '配饰', '包包', '其他'];

  List<Clothe> get _filteredClothes {
    var list = _state.currentClothes;
    if (_category != '全部') list = list.where((c) => c.category == _category).toList();
    if (_search.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showWardrobeDrawer,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_state.currentWardrobe?.name ?? '选择衣柜',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_state.isSyncing || _state.isAdding ? Icons.sync : Icons.cloud_done,
                color: (_state.isSyncing || _state.isAdding) ? Colors.orange : Colors.green),
            onPressed: () => _state.sync(),
            tooltip: _state.syncStatus,
          ),
        ],
      ),
      body: _state.currentWardrobe == null
          ? _buildEmptyWardrobe()
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Column(
                children: [
                  if (_isRefreshing)
                    const LinearProgressIndicator(minHeight: 2, color: Color(0xFF5C2E0A)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '搜索衣物...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: categories.length,
                      itemBuilder: (_, i) {
                        final cat = categories[i];
                        final active = _category == cat;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: active,
                            onSelected: (_) => setState(() => _category = cat),
                            selectedColor: const Color(0xFF5C2E0A),
                            labelStyle: TextStyle(color: active ? Colors.white : Colors.black54),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _filteredClothes.isEmpty
                        ? _buildEmptyClothes()
                        : GridView.builder(
                            padding: const EdgeInsets.all(10),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _filteredClothes.length,
                            itemBuilder: (_, i) => _buildClotheCard(_filteredClothes[i]),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _state.currentWardrobe != null &&
              _state.currentWardrobe!.owner == _state.username
          ? FloatingActionButton.extended(
              onPressed: _state.isAdding ? null : _showAddClotheDialog,
              icon: _state.isAdding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: Text(_state.isAdding ? '添加中...' : '添加衣物'),
            )
          : null,
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _state.sync();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Widget _buildEmptyWardrobe() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.checkroom, size: 80, color: Color(0xFFCCC0A8)),
          const SizedBox(height: 16),
          const Text('还没有衣柜', style: TextStyle(fontSize: 18, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text('创建一个衣柜，开始管理你的衣物', style: TextStyle(fontSize: 13, color: Colors.black38)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showCreateWardrobeDialog,
            icon: const Icon(Icons.add),
            label: const Text('创建第一个衣柜'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C2E0A)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyClothes() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2, size: 70, color: Color(0xFFCCC0A8)),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty || _category != '全部' ? '没有找到匹配的衣物' : '衣柜还是空的',
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          if (_state.currentWardrobe!.owner == _state.username && _search.isEmpty && _category == '全部') ...[
            const SizedBox(height: 8),
            const Text('点击右下角按钮添加第一件衣物', style: TextStyle(fontSize: 13, color: Colors.black38)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _showAddClotheDialog,
              icon: const Icon(Icons.add),
              label: const Text('添加衣物'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClotheCard(Clothe c) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showClotheDetail(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: c.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: c.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFFF0E8D8), child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5C2E0A))))),
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFFF0E8D8), child: const Center(child: Icon(Icons.broken_image, color: Colors.white30))),
                    )
                  : Container(color: const Color(0xFFF0E8D8), child: const Center(child: Icon(Icons.checkroom, size: 40, color: Colors.white30))),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${c.category}${c.color.isNotEmpty ? " · ${c.color}" : ""}',
                      style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWardrobeDrawer() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('我的衣柜', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('点击切换衣柜，共享衣柜可与对方互通', style: TextStyle(fontSize: 12, color: Colors.black38)),
              const SizedBox(height: 12),
              ..._state.visibleWardrobes.map((w) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF5C2E0A).withOpacity(0.15),
                      child: const Icon(Icons.checkroom, color: Color(0xFF5C2E0A)),
                    ),
                    title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${w.owner} · ${_state.wardrobeData[w.id]?.clothes.length ?? 0} 件衣物'),
                    trailing: w.visibility == 'shared' ? const Chip(label: Text('共享', style: TextStyle(fontSize: 10)), padding: EdgeInsets.zero) : null,
                    selected: w.id == _state.currentWardrobeId,
                    onTap: () {
                      _state.switchWardrobe(w.id);
                      Navigator.pop(ctx);
                    },
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle, color: Color(0xFF5C2E0A)),
                title: const Text('新建衣柜', style: TextStyle(color: Color(0xFF5C2E0A))),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateWardrobeDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateWardrobeDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String visibility = 'shared'; // 默认共享，方便推荐
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建衣柜'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '衣柜名称 *'), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述（可选）')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: visibility,
                decoration: const InputDecoration(labelText: '可见性'),
                items: const [
                  DropdownMenuItem(value: 'shared', child: Text('共享（推荐，可互相推荐衣物）')),
                  DropdownMenuItem(value: 'private', child: Text('私有（仅自己可见）')),
                ],
                onChanged: (v) => setDialogState(() => visibility = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await _state.createWardrobe(nameCtrl.text.trim(), descCtrl.text.trim(), visibility);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C2E0A)),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  List<File> _pickedImages = [];
  void _showAddClotheDialog() {
    final nameCtrls = <TextEditingController>[];
    final brandCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = '上衣';
    String color = '';
    String season = '';
    _pickedImages = [];
    bool submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('添加衣物')),
              Text('${_pickedImages.length} 张', style: const TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图片选择区域
                GestureDetector(
                  onTap: () async {
                    final List<XFile> imgs = await _picker.pickMultiImage(imageQuality: 70) ?? [];
                    if (imgs.isNotEmpty) {
                      setDialogState(() {
                        _pickedImages = imgs.map((f) => File(f.path)).toList();
                        nameCtrls.clear();
                        for (int i = 0; i < _pickedImages.length; i++) {
                          nameCtrls.add(TextEditingController(text: '衣物${i + 1}'));
                        }
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: _pickedImages.isEmpty ? 120 : 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0E8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDDD0B8)),
                    ),
                    child: _pickedImages.isEmpty
                        ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.photo_library, size: 32, color: Color(0xFF5C2E0A)),
                            SizedBox(height: 6),
                            Text('点击选择多张图片', style: TextStyle(color: Colors.black45, fontSize: 13)),
                          ])
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(8),
                            itemCount: _pickedImages.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(_pickedImages[i], width: 70, height: 84, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: -6,
                                    right: -6,
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red, size: 18),
                                      onPressed: () => setDialogState(() {
                                        _pickedImages.removeAt(i);
                                        nameCtrls.removeAt(i);
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
                if (_pickedImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerLeft, child: Text('统一设置（应用到所有衣物）', style: TextStyle(fontSize: 12, color: Colors.black45))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: '分类', isDense: true),
                    items: categories.where((c) => c != '全部').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => category = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: TextEditingController(text: color), decoration: const InputDecoration(labelText: '颜色', isDense: true), onChanged: (v) => color = v),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: season.isEmpty ? '四季' : season,
                    decoration: const InputDecoration(labelText: '季节', isDense: true),
                    items: ['四季', '春', '夏', '秋', '冬'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDialogState(() => season = v!),
                  ),
                  const SizedBox(height: 12),
                  // 每个衣物的名称编辑
                  const Align(alignment: Alignment.centerLeft, child: Text('衣物名称（可逐个修改）', style: TextStyle(fontSize: 12, color: Colors.black45))),
                  const SizedBox(height: 6),
                  ...List.generate(_pickedImages.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(_pickedImages[i], width: 32, height: 32, fit: BoxFit.cover)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: nameCtrls[i], decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10)))),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: submitting || _pickedImages.isEmpty
                  ? null
                  : () async {
                      for (final ctrl in nameCtrls) {
                        if (ctrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请填写所有衣物名称')));
                          return;
                        }
                      }
                      setDialogState(() => submitting = true);
                      final clothesList = <Map<String, dynamic>>[];
                      for (int i = 0; i < _pickedImages.length; i++) {
                        final bytes = await _pickedImages[i].readAsBytes();
                        final clothe = Clothe(
                          id: 'clothe-${DateTime.now().millisecondsSinceEpoch}-$i-${_state.currentClothes.length}',
                          name: nameCtrls[i].text.trim(),
                          category: category,
                          color: color,
                          season: season == '四季' ? '' : season,
                          brand: brandCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        clothesList.add({'clothe': clothe, 'bytes': bytes});
                      }
                      await _state.addClothesBatch(clothesList);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('已添加 ${clothesList.length} 件衣物，后台同步中...')));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C2E0A)),
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_pickedImages.length > 1 ? '批量添加 ${_pickedImages.length} 件' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClotheDetail(Clothe c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.imageUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: c.imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover)
            else
              Container(height: 160, color: const Color(0xFFF0E8D8), child: const Center(child: Icon(Icons.checkroom, size: 50, color: Colors.white30))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    if (c.category.isNotEmpty) _tag(c.category),
                    if (c.color.isNotEmpty) _tag(c.color),
                    if (c.season.isNotEmpty) _tag(c.season),
                    if (c.brand.isNotEmpty) _tag(c.brand),
                  ]),
                  if (c.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(c.notes, style: const TextStyle(color: Colors.black54, fontSize: 14)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 推荐给TA按钮（仅当有可推荐的共享衣柜时显示）
          if (_state.recommendableWardrobes.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToRecommendWithClothe(c);
              },
              icon: const Icon(Icons.favorite, color: Color(0xFF5C2E0A)),
              label: const Text('推荐给TA', style: TextStyle(color: Color(0xFF5C2E0A))),
            ),
          if (_state.currentWardrobe?.owner == _state.username)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _state.deleteClothe(c.id);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _navigateToRecommendWithClothe(Clothe c) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecommendScreen(preselectedClotheId: c.id),
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFF5C2E0A).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF3D1E08))),
      );
}
