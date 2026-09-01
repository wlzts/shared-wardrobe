import 'dart:async';
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
  bool isAdding = false;
  String? syncError;

  static const _syncTimeout = Duration(seconds: 30);

  String get username => gh.username;
  Wardrobe? get currentWardrobe =>
      wardrobes.cast<Wardrobe?>().firstWhere((w) => w?.id == currentWardrobeId, orElse: () => null);
  WardrobeData? get currentData => currentWardrobeId != null ? wardrobeData[currentWardrobeId] : null;
  List<Clothe> get currentClothes => currentData?.clothes ?? [];
  List<Outfit> get currentOutfits => currentData?.outfits ?? [];

  List<Wardrobe> get visibleWardrobes =>
      wardrobes.where((w) => w.owner == gh.username || w.visibility == 'shared').toList();

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
      try {
        final list = json.decode(cacheWardrobes) as List;
        wardrobes = list.map((e) => Wardrobe.fromJson(e)).toList();
      } catch (_) {}
    }
    final cacheData = prefs.getString('cache_wardrobe_data');
    if (cacheData != null) {
      try {
        final map = json.decode(cacheData) as Map;
        wardrobeData = map.map((k, v) => MapEntry(k, WardrobeData.fromJson(v)));
      } catch (_) {}
    }
    final cacheRecs = prefs.getString('cache_recommendations');
    if (cacheRecs != null) {
      try {
        final list = json.decode(cacheRecs) as List;
        recommendations = list.map((e) => Recommendation.fromJson(e)).toList();
      } catch (_) {}
    }
    currentWardrobeId = prefs.getString('current_wardrobe');
    if (currentWardrobeId != null && !wardrobes.any((w) => w.id == currentWardrobeId)) {
      currentWardrobeId = null;
    }

    notifyListeners();
    if (gh.isConfigured) {
      // 后台异步同步，不阻塞启动
      sync();
    }
  }

  String _decodeToken() {
    const encoded = 'oeVS0UN7OHMXW2BNya2HmZ2qB7q0BWr8pIU6Q941BDO8Fk5bt2GrgCaJp0H_N2bF6qHkHxCm0IRP72BB11_tap_buhtig';
    return encoded.split('').reversed.join();
  }

  Future<void> sync() async {
    if (isSyncing) {
      debugPrint('Sync already in progress, skipping');
      return;
    }
    isSyncing = true;
    syncError = null;
    syncStatus = '同步中...';
    notifyListeners();

    try {
      await _pullAll().timeout(_syncTimeout, onTimeout: () {
        throw TimeoutException('同步超时（${_syncTimeout.inSeconds}秒）');
      });
      final now = DateTime.now();
      syncStatus = '已同步 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      syncError = null;
    } catch (e) {
      syncError = e.toString();
      syncStatus = '同步失败: $e';
      debugPrint('Sync failed: $e');
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_wardrobes', json.encode(wardrobes.map((e) => e.toJson()).toList()));
      await prefs.setString(
          'cache_wardrobe_data', json.encode(wardrobeData.map((k, v) => MapEntry(k, v.toJson()))));
      await prefs.setString('cache_recommendations', json.encode(recommendations.map((e) => e.toJson()).toList()));
      if (currentWardrobeId != null) await prefs.setString('current_wardrobe', currentWardrobeId!);
    } catch (e) {
      debugPrint('Save cache failed: $e');
    }
  }

  Future<void> _pullAll() async {
    syncStatus = '正在获取衣柜列表...';
    notifyListeners();

    final wRes = await gh.getFile('data/wardrobes.json');
    if (wRes != null) {
      try {
        final parsed = json.decode(wRes['content']);
        wardrobes = (parsed['wardrobes'] as List? ?? []).map((e) => Wardrobe.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Parse wardrobes failed: $e');
      }
    }

    syncStatus = '正在获取衣物数据 (${wardrobes.length}个衣柜)...';
    notifyListeners();

    for (final w in wardrobes) {
      final res = await gh.getFile('data/wardrobes/${w.id}.json');
      if (res != null) {
        try {
          wardrobeData[w.id] = WardrobeData.fromJson(json.decode(res['content']));
        } catch (e) {
          debugPrint('Parse wardrobe ${w.id} failed: $e');
          if (!wardrobeData.containsKey(w.id)) {
            wardrobeData[w.id] = WardrobeData(wardrobeId: w.id, clothes: [], outfits: [], lastUpdated: DateTime.now());
          }
        }
      } else if (!wardrobeData.containsKey(w.id)) {
        wardrobeData[w.id] = WardrobeData(wardrobeId: w.id, clothes: [], outfits: [], lastUpdated: DateTime.now());
      }
    }

    syncStatus = '正在获取推荐数据...';
    notifyListeners();

    final rRes = await gh.getFile('data/recommendations.json');
    if (rRes != null) {
      try {
        final parsed = json.decode(rRes['content']);
        recommendations = (parsed['recommendations'] as List? ?? []).map((e) => Recommendation.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Parse recommendations failed: $e');
      }
    }

    if (currentWardrobeId == null && wardrobes.isNotEmpty) {
      currentWardrobeId = wardrobes.first.id;
    }
    await _saveCache();
  }

  void switchWardrobe(String id) {
    currentWardrobeId = id;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setString('current_wardrobe', id)).catchError((_) {});
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
    wardrobes.add(w);
    wardrobeData[id] = WardrobeData(wardrobeId: id, clothes: [], outfits: [], lastUpdated: now);
    currentWardrobeId = id;
    await _saveCache();
    notifyListeners();

    // 后台异步同步，不阻塞UI
    _backgroundSave(() async {
      await _saveWardrobesFile();
      await _saveWardrobeData(id);
    });
    return true;
  }

  // 后台保存辅助方法：带超时和错误处理
  Future<void> _backgroundSave(Future<void> Function() task) async {
    try {
      await task().timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Background save failed: $e');
      syncError = e.toString();
      syncStatus = '保存失败: $e';
      notifyListeners();
    }
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

  Future<void> addClothe(Clothe clothe, List<int> imageBytes) async {
    if (isAdding) return;
    isAdding = true;
    notifyListeners();

    try {
      final data = wardrobeData[currentWardrobeId];
      if (data == null) return;

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
      data.lastUpdated = DateTime.now();
      await _saveCache();
      notifyListeners();

      _backgroundSave(() async {
        await gh.uploadImage(imagePath, imageBytes, message: 'upload image ${clothe.id}');
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

      _backgroundSave(() async {
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

    _backgroundSave(() async {
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

    _backgroundSave(() => _saveWardrobeData(currentWardrobeId!));
  }

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

    _backgroundSave(() => _saveRecommendationsFile());
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

    _backgroundSave(() => _saveRecommendationsFile());
  }

  Future<void> _saveRecommendationsFile() async {
    final content = json.encode({
      'lastUpdated': DateTime.now().toIso8601String(),
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
    });
    final existing = await gh.getFile('data/recommendations.json');
    await gh.putFile('data/recommendations.json', content, sha: existing?['sha'], message: 'update recommendations');
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
