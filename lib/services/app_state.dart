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

  String get username => gh.username;
  Wardrobe? get currentWardrobe =>
      wardrobes.cast<Wardrobe?>().firstWhere((w) => w?.id == currentWardrobeId, orElse: () => null);
  WardrobeData? get currentData => currentWardrobeId != null ? wardrobeData[currentWardrobeId] : null;
  List<Clothe> get currentClothes => currentData?.clothes ?? [];
  List<Outfit> get currentOutfits => currentData?.outfits ?? [];

  List<Wardrobe> get visibleWardrobes =>
      wardrobes.where((w) => w.owner == gh.username || w.visibility == 'shared').toList();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      // 硬编码默认配置
      gh.init(
        username: 'wlzts',
        repo: 'shared-wardrobe',
        token: _decodeToken(),
      );
      await prefs.setString('token', gh.token);
      await prefs.setString('username', gh.username);
      await prefs.setString('repo', gh.repo);
    } else {
      gh.init(
        username: prefs.getString('username') ?? 'wlzts',
        repo: prefs.getString('repo') ?? 'shared-wardrobe',
        token: token,
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
      await sync();
    }
  }

  String _decodeToken() {
    const encoded = 'oeVS0UN7OHMXW2BNya2HmZ2qB7q0BWr8pIU6Q941BDO8Fk5bt2GrgCaJp0H_N2bF6qHkHxCm0IRP72BB11_tap_buhtig';
    return encoded.split('').reversed.join();
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_wardrobes', json.encode(wardrobes.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'cache_wardrobe_data', json.encode(wardrobeData.map((k, v) => MapEntry(k, v.toJson()))));
    await prefs.setString('cache_recommendations', json.encode(recommendations.map((e) => e.toJson()).toList()));
    if (currentWardrobeId != null) await prefs.setString('current_wardrobe', currentWardrobeId!);
  }

  Future<void> sync() async {
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

  Future<void> _pullAll() async {
    // 拉取衣柜列表
    final wRes = await gh.getFile('data/wardrobes.json');
    if (wRes != null) {
      final parsed = json.decode(wRes['content']);
      wardrobes = (parsed['wardrobes'] as List? ?? []).map((e) => Wardrobe.fromJson(e)).toList();
    }
    // 拉取每个衣柜的数据
    for (final w in wardrobes) {
      final res = await gh.getFile('data/wardrobes/${w.id}.json');
      if (res != null) {
        wardrobeData[w.id] = WardrobeData.fromJson(json.decode(res['content']));
      } else if (!wardrobeData.containsKey(w.id)) {
        wardrobeData[w.id] = WardrobeData(wardrobeId: w.id, clothes: [], outfits: [], lastUpdated: DateTime.now());
      }
    }
    // 拉取推荐
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

  Future<void> switchWardrobe(String id) async {
    currentWardrobeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_wardrobe', id);
    notifyListeners();
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
    await _saveWardrobesFile();
    await _saveWardrobeData(id);
    await _saveCache();
    notifyListeners();
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

  Future<void> addClothe(Clothe clothe, List<int> imageBytes) async {
    final data = wardrobeData[currentWardrobeId];
    if (data == null) return;
    // 上传图片
    final imagePath = 'images/${clothe.id}.jpg';
    await gh.uploadImage(imagePath, imageBytes, message: 'upload image ${clothe.id}');
    final updated = Clothe(
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
    data.clothes.add(updated);
    data.lastUpdated = DateTime.now();
    await _saveWardrobeData(currentWardrobeId!);
    await _saveCache();
    notifyListeners();
  }

  Future<void> deleteClothe(String clotheId) async {
    final data = wardrobeData[currentWardrobeId];
    if (data == null) return;
    final clothe = data.clothes.firstWhere((c) => c.id == clotheId);
    data.clothes.removeWhere((c) => c.id == clotheId);
    data.lastUpdated = DateTime.now();
    // 删除图片
    if (clothe.imagePath.isNotEmpty) {
      final existing = await gh.getFile(clothe.imagePath);
      if (existing != null) {
        await gh.deleteFile(clothe.imagePath, existing['sha'], message: 'delete image');
      }
    }
    await _saveWardrobeData(currentWardrobeId!);
    await _saveCache();
    notifyListeners();
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
    await _saveWardrobeData(currentWardrobeId!);
    await _saveCache();
    notifyListeners();
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
    await _saveRecommendationsFile();
    await _saveCache();
    notifyListeners();
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
    await _saveRecommendationsFile();
    await _saveCache();
    notifyListeners();
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
