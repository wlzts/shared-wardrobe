import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    return Scaffold(
      appBar: AppBar(title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // GitHub 配置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.cloud, color: Color(0xFFB8860B), size: 20), SizedBox(width: 8), Text('GitHub 同步', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 12),
                  _infoRow('用户名', state.username),
                  _infoRow('仓库', '${state.gh.repo}'),
                  _infoRow('分支', state.gh.branch),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isSyncing ? null : () => state.sync(),
                          icon: Icon(state.isSyncing ? Icons.sync : Icons.refresh, size: 18),
                          label: Text(state.isSyncing ? '同步中...' : '手动同步'),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB8860B), side: const BorderSide(color: Color(0xFFB8860B))),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 同步状态
          Card(
            child: ListTile(
              leading: Icon(state.isSyncing ? Icons.sync : Icons.cloud_done, color: state.isSyncing ? Colors.orange : Colors.green),
              title: const Text('同步状态'),
              subtitle: Text(state.syncStatus),
            ),
          ),
          const SizedBox(height: 10),

          // 数据管理
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('清除本地数据'),
                  subtitle: const Text('清除缓存，下次打开重新从 GitHub 拉取'),
                  onTap: () => _showClearConfirm(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.black45),
                  title: const Text('关于'),
                  subtitle: const Text('共享衣柜 v1.0.0\n基于 GitHub 的多设备同步衣柜管理'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('数据存储在你的 GitHub 仓库中\n两台设备登录同一账号即可同步', style: TextStyle(fontSize: 12, color: Colors.black38), textAlign: TextAlign.center)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.black45, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showClearConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除本地数据'),
        content: const Text('确定清除所有本地缓存数据吗？\nGitHub 仓库中的数据不会被删除，下次打开会重新拉取。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('cache_wardrobes');
              await prefs.remove('cache_wardrobe_data');
              await prefs.remove('cache_recommendations');
              await prefs.remove('current_wardrobe');
              AppState().wardrobes = [];
              AppState().wardrobeData = {};
              AppState().recommendations = [];
              AppState().currentWardrobeId = null;
              AppState().notifyListeners();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('本地数据已清除')));
              }
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
