import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/app_state.dart';
import '../models/models.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    final clothes = state.currentClothes;
    final outfits = state.currentOutfits;

    if (state.currentWardrobe == null) {
      return const Scaffold(body: Center(child: Text('请先选择衣柜', style: TextStyle(color: Colors.black45))));
    }

    // 分类统计
    final categoryCount = <String, int>{};
    for (final c in clothes) {
      categoryCount[c.category] = (categoryCount[c.category] ?? 0) + 1;
    }
    final sortedCategories = categoryCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // 颜色统计
    final colorCount = <String, int>{};
    for (final c in clothes) {
      if (c.color.isNotEmpty) colorCount[c.color] = (colorCount[c.color] ?? 0) + 1;
    }

    // 季节统计
    final seasonCount = <String, int>{};
    for (final c in clothes) {
      final s = c.season.isEmpty ? '四季' : c.season;
      seasonCount[s] = (seasonCount[s] ?? 0) + 1;
    }

    const chartColors = [Color(0xFFB8860B), Color(0xFFD4A01E), Color(0xFF8B6508), Color(0xFFCD853F), Color(0xFFDEB887), Color(0xFFF4A460), Color(0xFFDAA520)];

    return Scaffold(
      appBar: AppBar(title: const Text('统计', style: TextStyle(fontWeight: FontWeight.bold))),
      body: clothes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.bar_chart, size: 70, color: Color(0xFFCCC0A8)),
                  SizedBox(height: 12),
                  Text('添加衣物后查看统计', style: TextStyle(color: Colors.black45)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 概览卡片
                Row(
                  children: [
                    Expanded(child: _statCard('衣物总数', '${clothes.length}', Icons.checkroom)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('穿搭记录', '${outfits.length}', Icons.calendar_today)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _statCard('分类数', '${categoryCount.length}', Icons.category)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('颜色数', '${colorCount.length}', Icons.palette)),
                  ],
                ),
                const SizedBox(height: 16),

                // 分类分布
                if (sortedCategories.isNotEmpty) ...[
                  const Text('分类分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 220,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: sortedCategories.length <= 6
                            ? PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: List.generate(sortedCategories.length, (i) {
                                    final e = sortedCategories[i];
                                    final pct = (e.value / clothes.length * 100).toStringAsFixed(0);
                                    return PieChartSectionData(
                                      color: chartColors[i % chartColors.length],
                                      value: e.value.toDouble(),
                                      title: '$pct%',
                                      radius: 50,
                                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }),
                                ),
                              )
                            : BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  barGroups: List.generate(sortedCategories.length, (i) {
                                    final e = sortedCategories[i];
                                    return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: e.value.toDouble(), color: chartColors[i % chartColors.length], width: 16, borderRadius: BorderRadius.circular(4))]);
                                  }),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 || idx >= sortedCategories.length) return const SizedBox.shrink();
                                          return Padding(padding: const EdgeInsets.only(top: 4), child: Text(sortedCategories[idx].key, style: const TextStyle(fontSize: 10)));
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: List.generate(sortedCategories.length, (i) {
                      final e = sortedCategories[i];
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: chartColors[i % chartColors.length], borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ]);
                    }),
                  ),
                  const SizedBox(height: 16),
                ],

                // 季节分布
                if (seasonCount.isNotEmpty) ...[
                  const Text('季节分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: seasonCount.entries.map((e) {
                          final pct = e.value / clothes.length;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(width: 40, child: Text(e.key, style: const TextStyle(fontSize: 13))),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(value: pct, minHeight: 16, backgroundColor: const Color(0xFFF0E8D8), valueColor: const AlwaysStoppedAnimation(Color(0xFFB8860B))),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${e.value}件', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 颜色分布
                if (colorCount.isNotEmpty) ...[
                  const Text('颜色分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: colorCount.entries.map((e) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 44, height: 44, decoration: BoxDecoration(color: _colorFromName(e.key), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12))),
                              const SizedBox(height: 4),
                              Text(e.key, style: const TextStyle(fontSize: 11)),
                              Text('${e.value}件', style: const TextStyle(fontSize: 10, color: Colors.black45)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFB8860B), size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Color _colorFromName(String name) {
    const map = {
      '黑': Colors.black, '白': Colors.white, '灰': Colors.grey, '红': Colors.red, '橙': Colors.orange,
      '黄': Colors.yellow, '绿': Colors.green, '蓝': Colors.blue, '紫': Colors.purple, '粉': Colors.pink,
      '棕': Colors.brown, '米': Color(0xFFF5F5DC), '卡其': Color(0xFFC3B091), '牛仔': Color(0xFF1560BD),
    };
    for (final entry in map.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return const Color(0xFFCCC0A8);
  }
}
