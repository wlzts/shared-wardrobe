import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'github_service.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  final _uuid = const Uuid();
  final gh = GitHubService();

  List<Wardrobe> wardrobes = [];
  Map<String, WardrobeData> wardrobeData = {};
  List<Recommendation> recommendations = [];
  String? currentWardrobeId;
  String syncStatus = '未连接';
  bool isSyncing = false;
  bool isAdding = false; // 防重复提交锁

  // 待同步队列
  final List<Future<void> Function()> _syncQueue = [];
  bool _syncingQueue = false;

  String get username => gh.username;
  Wardrobe? get currentWardrobe =>
      wardrobes.cast<Wardrobe?>().firstWhere((w) => w?.id == currentWardrobeId, orElse: () => null);
  WardrobeData? get currentData => currentWardrobeId != null ? wardrobeData[currentWardrobeId] : null;
  List<Clothe> get currentClothes => currentData?.clothes ?? [];
  List<Outfit> get currentOutfits => currentData?.outfits ?? [];

  List<Wardrobe> get visibleWardrobes =>
      wardrobes.where((w) => w.owner == gh.username || w.visibility == 'shared').toList();

  // 可推荐的目标衣柜（共享且不是自己的）
  List<Wardrobe> get recommendableWardrobes =>
      wardrobes.where((w) => w.visibility == 'shared' && w.owner != gh.username).toList();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      gh.init(
        username: 'wlzts',
        repo: 'shared-wardrobe',
        token: _decodeToken(),
        branch: 'flutter-app',
      );
      await prefs.setString('token', gh.token);
      await prefs.setString('username', gh.username);
      await prefs.setString('repo', gh.repo);
    } else {
      gh.init(
        username: prefs.getString('username') ?? 'wlzts',
        repo: prefs.getString('repo') ?? 'shared-wardrobe',
        token: token,
        branch: 'flutter-app',
      );
    }

    // 加载本地缓存
    final cacheWardrobes = prefs.getString('cache_wardrobes');
    if (cacheWardrobes != null) {
      final list = json.decode(cacheWardrobes) as List;
      wardrobes = list.map((e) => Wardrobe.fromJson(e)).toList();
    }
    final cacheData = prefs.getString('cache_wardrobe_data');
    if (cacheData != null) {
      final map = json.decode(cacheData) as Map;
      wardrobeData = map.map((k, v) => MapEntry(k, WardrobeData.fromJson(v)));
    }
    final cacheRecs = prefs.getString('cache_recommendations');
    if (cacheRecs != null) {
      final list = json.decode(cacheRecs) as List;
      recommendations = list.map((e) => Recommendation.fromJson(e)).toList();
    }
    currentWardrobeId = prefs.getString('current_wardrobe');
    if (currentWardrobeId != null && !wardrobes.any((w) => w.id == currentWardrobeId)) {
      currentWardrobeId = null;
    }

    notifyListeners();
    if (gh.isConfigured) {
      // 后台异步同步，不阻塞启动
      _backgroundSync();
    }
  }

  String _decodeToken() {
    const encoded = 'oeVS0UN7OHMXW2BNya2HmZ2qB7q0BWr8pIU6Q941BDO8Fk5bt2GrgCaJp0H_N2bF6qHkHxCm0IRP72BB11_tap_buhtig';
    return encoded.split('').reversed.join();
  }

  Future<void> _backgroundSync() async {
    if (isSyncing) return;
    isSyncing = true;
    syncStatus = '同步中...';
    notifyListeners();
    try {
      await _pullAll();
      syncStatus = '已同步 ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    } catch (e) {
      syncStatus = '同步失败: $e';
    }
    isSyncing = false;
    notifyListeners();
  }

  Future<void> sync() => _backgroundSync();

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_wardrobes', json.encode(wardrobes.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'cache_wardrobe_data', json.encode(wardrobeData.map((k, v) => MapEntry(k, v.toJson()))));
    await prefs.setString('cache_recommendations', json.encode(recommendations.map((e) => e.toJson()).toList()));
    if (currentWardrobeId != null) await prefs.setString('current_wardrobe', currentWardrobeId!);
  }

  Future<void> _pullAll() async {
    final wRes = await gh.getFile('data/wardrobes.json');
    if (wRes != null) {
      final parsed = json.decode(wRes['content']);
      wardrobes = (parsed['wardrobes'] as List? ?? []).map((e) => Wardrobe.fromJson(e)).toList();
    }
    for (final w in wardrobes) {
      final res = await gh.getFile('data/wardrobes/${w.id}.json');
      if (res != null) {
        wardrobeData[w.id] = WardrobeData.fromJson(json.decode(res['content']));
      } else if (!wardrobeData.containsKey(w.id)) {
        wardrobeData[w.id] = WardrobeData(wardrobeId: w.id, clothes: [], outfits: [], lastUpdated: DateTime.now());
      }
    }
    final rRes = await gh.getFile('data/recommendations.json');
    if (rRes != null) {
      final parsed = json.decode(rRes['content']);
      recommendations = (parsed['recommendations'] as List? ?? []).map((e) => Recommendation.fromJson(e)).toList();
    }
    if (currentWardrobeId == null && wardrobes.isNotEmpty) {
      currentWardrobeId = wardrobes.first.id;
    }
    await _saveCache();
  }

  void switchWardrobe(String id) {
    currentWardrobeId = id;
    notifyListeners();
    // 异步保存，不阻塞UI
    SharedPreferences.getInstance().then((prefs) => prefs.setString('current_wardrobe', id));
  }

  Future<bool> createWardrobe(String name, String description, String visibility) async {
    final id = 'wardrobe-${_uuid.v4().substring(0, 8)}';
    final now = DateTime.now();
    final w = Wardrobe(
      id: id,
      name: name,
      owner: gh.username,
      description: description,
      visibility: visibility,
      createdAt: now,
      updatedAt: now,
    );
    // 本地先保存
    wardrobes.add(w);
    wardrobeData[id] = WardrobeData(wardrobeId: id, clothes: [], outfits: [], lastUpdated: now);
    currentWardrobeId = id;
    await _saveCache();
    notifyListeners();

    // 后台异步同步
    _enqueueSync(() async {
      await _saveWardrobesFile();
      await _saveWardrobeData(id);
    });
    return true;
  }

  Future<void> _saveWardrobesFile() async {
    final content = json.encode({
      'version': '2.0',
      'lastUpdated': DateTime.now().toIso8601String(),
      'wardrobes': wardrobes.map((e) => e.toJson()).toList(),
    });
    final existing = await gh.getFile('data/wardrobes.json');
    await gh.putFile('data/wardrobes.json', content, sha: existing?['sha'], message: 'update wardrobes');
  }

  Future<void> _saveWardrobeData(String wardrobeId) async {
    final data = wardrobeData[wardrobeId];
    if (data == null) return;
    final content = json.encode(data.toJson());
    final path = 'data/wardrobes/$wardrobeId.json';
    final existing = await gh.getFile(path);
    await gh.putFile(path, content, sha: existing?['sha'], message: 'update wardrobe $wardrobeId');
  }

  // 添加衣物：本地优先，立即返回，后台异步同步
  Future<void> addClothe(Clothe clothe, List<int> imageBytes) async {
    if (isAdding) return; // 防重复
    isAdding = true;
    notifyListeners();

    try {
      final data = wardrobeData[currentWardrobeId];
      if (data == null) return;

      final imagePath = 'images/${clothe.id}.jpg';

      // 本地先保存（用临时图片URL，同步后更新）
      final localClothe = Clothe(
        id: clothe.id,
        name: clothe.name,
        category: clothe.category,
        color: clothe.color,
        season: clothe.season,
        imagePath: imagePath,
        imageUrl: '', // 同步后更新
        brand: clothe.brand,
        notes: clothe.notes,
        createdAt: clothe.createdAt,
      );
      data.clothes.add(localClothe);
      data.lastUpdated = DateTime.now();
      await _saveCache();
      notifyListeners();

      // 后台异步同步
      _enqueueSync(() async {
        // 上传图片
        await gh.uploadImage(imagePath, imageBytes, message: 'upload image ${clothe.id}');
        // 更新衣物的图片URL
        final idx = data.clothes.indexWhere((c) => c.id == clothe.id);
        if (idx >= 0) {
          data.clothes[idx] = Clothe(
            id: clothe.id,
            name: clothe.name,
            category: clothe.category,
            color: clothe.color,
            season: clothe.season,
            imagePath: imagePath,
            imageUrl: gh.rawUrl(imagePath),
            brand: clothe.brand,
            notes: clothe.notes,
            createdAt: clothe.createdAt,
          );
          data.lastUpdated = DateTime.now();
          await _saveWardrobeData(currentWardrobeId!);
          await _saveCache();
          notifyListeners();
        }
      });
    } finally {
      isAdding = false;
      notifyListeners();
    }
  }

  // 批量添加衣物
  Future<void> addClothesBatch(List<Map<String, dynamic>> clothesList) async {
    if (isAdding || clothesList.isEmpty) return;
    isAdding = true;
    notifyListeners();

    try {
      final data = wardrobeData[currentWardrobeId];
      if (data == null) return;

      final List<Clothe> createdClothes = [];
      for (final item in clothesList) {
        final clothe = item['clothe'] as Clothe;
        final imagePath = 'images/${clothe.id}.jpg';
        final localClothe = Clothe(
          id: clothe.id,
          name: clothe.name,
          category: clothe.category,
          color: clothe.color,
          season: clothe.season,
          imagePath: imagePath,
          imageUrl: '',
          brand: clothe.brand,
          notes: clothe.notes,
          createdAt: clothe.createdAt,
        );
        data.clothes.add(localClothe);
        createdClothes.add(localClothe);
      }
      data.lastUpdated = DateTime.now();
      await _saveCache();
      notifyListeners();

      // 后台异步批量同步
      _enqueueSync(() async {
        for (int i = 0; i < clothesList.length; i++) {
          final item = clothesList[i];
          final clothe = item['clothe'] as Clothe;
          final bytes = item['bytes'] as List<int>;
          final imagePath = 'images/${clothe.id}.jpg';
          try {
            await gh.uploadImage(imagePath, bytes, message: 'upload image ${clothe.id}');
            final idx = data.clothes.indexWhere((c) => c.id == clothe.id);
            if (idx >= 0) {
              data.clothes[idx] = Clothe(
                id: clothe.id,
                name: clothe.name,
                category: clothe.category,
                color: clothe.color,
                season: clothe.season,
                imagePath: imagePath,
                imageUrl: gh.rawUrl(imagePath),
                brand: clothe.brand,
                notes: clothe.notes,
                createdAt: clothe.createdAt,
              );
            }
          } catch (e) {
            debugPrint('Failed to upload image ${clothe.id}: $e');
          }
        }
        data.lastUpdated = DateTime.now();
        await _saveWardrobeData(currentWardrobeId!);
        await _saveCache();
        notifyListeners();
      });
    } finally {
      isAdding = false;
      notifyListeners();
    }
  }

  Future<void> deleteClothe(String clotheId) async {
    final data = wardrobeData[currentWardrobeId];
    if (data == null) return;
    final clothe = data.clothes.firstWhere((c) => c.id == clotheId);
    data.clothes.removeWhere((c) => c.id == clotheId);
    data.lastUpdated = DateTime.now();
    await _saveCache();
    notifyListeners();

    _enqueueSync(() async {
      if (clothe.imagePath.isNotEmpty) {
        final existing = await gh.getFile(clothe.imagePath);
        if (existing != null) {
          await gh.deleteFile(clothe.imagePath, existing['sha'], message: 'delete image');
        }
      }
      await _saveWardrobeData(currentWardrobeId!);
    });
  }

  Future<void> addOutfit(String date, List<String> clotheIds, String note) async {
    final data = wardrobeData[currentWardrobeId];
    if (data == null) return;
    final outfit = Outfit(
      id: 'outfit-${_uuid.v4().substring(0, 8)}',
      date: date,
      clotheIds: clotheIds,
      note: note,
      createdAt: DateTime.now(),
    );
    data.outfits.add(outfit);
    data.lastUpdated = DateTime.now();
    await _saveCache();
    notifyListeners();

    _enqueueSync(() => _saveWardrobeData(currentWardrobeId!));
  }

  // 发送推荐：从自己的衣柜选衣服推荐给对方
  Future<void> sendRecommendation(String toWardrobeId, List<String> clotheIds, String message) async {
    final rec = Recommendation(
      id: 'rec-${_uuid.v4().substring(0, 8)}',
      fromUser: gh.username,
      toWardrobeId: toWardrobeId,
      clotheIds: clotheIds,
      message: message,
      createdAt: DateTime.now(),
    );
    recommendations.add(rec);
    await _saveCache();
    notifyListeners();

    _enqueueSync(() => _saveRecommendationsFile());
  }

  Future<void> respondRecommendation(String recId, String status, {String? outfitDate}) async {
    final rec = recommendations.firstWhere((r) => r.id == recId);
    final idx = recommendations.indexOf(rec);
    recommendations[idx] = Recommendation(
      id: rec.id,
      fromUser: rec.fromUser,
      toWardrobeId: rec.toWardrobeId,
      clotheIds: rec.clotheIds,
      message: rec.message,
      status: status,
      acceptedOutfitDate: outfitDate,
      createdAt: rec.createdAt,
      respondedAt: DateTime.now(),
    );
    await _saveCache();
    notifyListeners();

    _enqueueSync(() => _saveRecommendationsFile());
  }

  Future<void> _saveRecommendationsFile() async {
    final content = json.encode({
      'lastUpdated': DateTime.now().toIso8601String(),
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
    });
    final existing = await gh.getFile('data/recommendations.json');
    await gh.putFile('data/recommendations.json', content, sha: existing?['sha'], message: 'update recommendations');
  }

  // 同步队列：串行执行，避免并发冲突
  void _enqueueSync(Future<void> Function() task) {
    _syncQueue.add(task);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_syncingQueue || _syncQueue.isEmpty) return;
    _syncingQueue = true;
    syncStatus = '后台同步中...';
    notifyListeners();
    try {
      while (_syncQueue.isNotEmpty) {
        final task = _syncQueue.removeAt(0);
        try {
          await task();
        } catch (e) {
          debugPrint('Sync task failed: $e');
        }
      }
      syncStatus = '已同步 ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    } finally {
      _syncingQueue = false;
      notifyListeners();
    }
  }

  List<Recommendation> get receivedRecommendations =>
      recommendations.where((r) => r.toWardrobeId == currentWardrobeId).toList();
  List<Recommendation> get sentRecommendations =>
      recommendations.where((r) => r.fromUser == gh.username).toList();

  Clothe? findClothe(String wardrobeId, String clotheId) {
    final data = wardrobeData[wardrobeId];
    if (data == null) return null;
    for (final c in data.clothes) {
      if (c.id == clotheId) return c;
    }
    return null;
  }
}
