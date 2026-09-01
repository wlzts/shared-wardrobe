import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 同步状态卡片（放在最前面，方便查看）
          Card(
            color: _state.syncError != null ? const Color(0xFFFFF3F0) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _state.isSyncing ? Icons.sync : (_state.syncError != null ? Icons.error_outline : Icons.cloud_done),
                        color: _state.isSyncing ? Colors.orange : (_state.syncError != null ? Colors.red : Colors.green),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _state.isSyncing ? '正在同步...' : (_state.syncError != null ? '同步失败' : '同步正常'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _state.syncStatus,
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      if (_state.isSyncing)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  if (_state.syncError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        '错误信息: ${_state.syncError}',
                        style: const TextStyle(fontSize: 12, color: Colors.red, height: 1.4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _state.isSyncing ? null : () => _state.sync(),
                          icon: Icon(_state.isSyncing ? Icons.sync : Icons.refresh, size: 18),
                          label: Text(_state.isSyncing ? '同步中...' : '重新同步'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5C2E0A),
                            side: const BorderSide(color: Color(0xFF5C2E0A)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statItem('衣柜', '${_state.wardrobes.length}'),
                      const SizedBox(width: 16),
                      _statItem('衣物', '${_state.currentClothes.length}'),
                      const SizedBox(width: 16),
                      _statItem('推荐', '${_state.recommendations.length}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // GitHub 配置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.settings_ethernet, color: Color(0xFF5C2E0A), size: 20), SizedBox(width: 8), Text('GitHub 配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 12),
                  _infoRow('用户名', _state.username),
                  _infoRow('仓库', _state.gh.repo),
                  _infoRow('分支', _state.gh.branch),
                  _infoRow('Token', _state.gh.token.isNotEmpty ? '已配置 (${_state.gh.token.substring(0, 12)}...)' : '未配置'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 使用说明
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.help_outline, color: Color(0xFF5C2E0A), size: 20), SizedBox(width: 8), Text('使用说明', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 12),
                  _helpItem('1. 创建衣柜', '点击衣柜页面顶部名称，选择"新建衣柜"，建议设为"共享"以便互相推荐'),
                  _helpItem('2. 添加衣物', '点击右下角"添加衣物"按钮，可一次选择多张图片批量添加'),
                  _helpItem('3. 推荐给TA', '在衣物详情页点击"推荐给TA"，或在推荐页面点击右上角发送按钮'),
                  _helpItem('4. 双设备同步', '两台手机登录同一 GitHub 账号，数据自动同步，下拉可手动刷新'),
                ],
              ),
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
                  subtitle: const Text('共享衣柜 v1.5.0\n基于 GitHub 的多设备同步衣柜管理'),
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

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5C2E0A))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black45)),
      ],
    );
  }

  Widget _helpItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF3D1E08))),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
              ],
            ),
          ),
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
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('本地数据已清除，正在重新同步...')));
                AppState().sync();
              }
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
