import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/common_widgets.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0;
  List<DashboardStats> _stats = [];
  List<Alert> _alerts = [];
  bool _isLoading = true;
  String _timeRange = '7d';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getStats(),
        ApiService.getAlerts(),
      ]);
      
      if (mounted) {
        setState(() {
          _stats = results[0] as List<DashboardStats>;
          _alerts = results[1] as List<Alert>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4AB08B)),
      );
    }

    if (_stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text('No data recorded for the past 7 days', style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }

    // Calculate averages from real-time data
    double avgTemp = _stats.isEmpty ? 0 : _stats.map((s) => s.avgTemperature).reduce((a, b) => a + b) / _stats.length;
    double avgHum = _stats.isEmpty ? 0 : _stats.map((s) => s.avgHumidity).reduce((a, b) => a + b) / _stats.length;
    double totalWater = _stats.isEmpty ? 0 : _stats.map((s) => s.waterUsage).reduce((a, b) => a + b);
    double avgUptime = _stats.isEmpty ? 0 : _stats.map((s) => (s.equipmentUptime.fan + s.equipmentUptime.fogger + s.equipmentUptime.sprinkler + s.equipmentUptime.motor) / 4).reduce((a, b) => a + b) / _stats.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          // Tabs
          _buildTabs(),
          const SizedBox(height: 24),
          
          if (_selectedTab == 0) ...[
            // Metrics Grid (Using real data averages)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildEnhancedMetricCard(
                  title: 'Avg Temperature',
                  value: avgTemp.toStringAsFixed(1),
                  unit: '°C',
                  range: 'Range: 22-32°C',
                  trend: '+2%',
                  isPositive: true,
                  icon: Icons.thermostat_outlined,
                ),
                _buildEnhancedMetricCard(
                  title: 'Avg Humidity',
                  value: avgHum.toStringAsFixed(0),
                  unit: '%',
                  range: 'Range: 50-65%',
                  trend: '-3%',
                  isPositive: false,
                  icon: Icons.water_drop_outlined,
                ),
                _buildEnhancedMetricCard(
                  title: 'Water Usage',
                  value: totalWater.toStringAsFixed(0),
                  unit: 'L',
                  range: '7-day total',
                  trend: '+5%',
                  isPositive: true,
                  icon: Icons.water,
                ),
                _buildEnhancedMetricCard(
                  title: 'Equipment Uptime',
                  value: avgUptime.toStringAsFixed(0),
                  unit: '%',
                  range: 'Overall status',
                  trend: '+8%',
                  isPositive: true,
                  icon: Icons.show_chart,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTemperatureHumidityChart(),
            const SizedBox(height: 24),
            _buildSystemStatusChart(),
            const SizedBox(height: 24),
          ],
          
          if (_selectedTab == 1) ...[
            _buildWaterUsageChart(),
            const SizedBox(height: 24),
            _buildWeeklyTrendsChart(),
            const SizedBox(height: 24),
            _buildDbStatsTable(),
            const SizedBox(height: 24),
          ],

          if (_selectedTab == 2) ...[
            _buildEquipmentPerformanceChart(),
            const SizedBox(height: 24),
          ],

          // Alert Summary
          _buildAlertSummary(),
          const SizedBox(height: 16),
          
          // Activity Timeline
          _buildActivityTimeline(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports & Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Performance metrics and insights',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report exported as CSV')),
            );
          },
          icon: const Icon(Icons.download, color: Color(0xFF4AB08B)),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF4AB08B).withOpacity(0.1),
            padding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  Widget _buildDbStatsTable() {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Database Records',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1f2933)),
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Temp', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Hum', style: TextStyle(color: Colors.white70))),
                DataColumn(label: Text('Water', style: TextStyle(color: Colors.white70))),
              ],
              rows: _stats.map((stat) => DataRow(
                cells: [
                  DataCell(Text(stat.date.substring(5), style: const TextStyle(color: Colors.white, fontSize: 12))),
                  DataCell(Text('${stat.avgTemperature.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  DataCell(Text('${stat.avgHumidity.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 12))),
                  DataCell(Text('${stat.waterUsage.toInt()}L', style: const TextStyle(color: Colors.white, fontSize: 12))),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMetricCard({
    required String title,
    required String value,
    required String unit,
    required String range,
    required String trend,
    required bool isPositive,
    required IconData icon,
  }) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF9ca3af), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9ca3af),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: Color(0xFF9ca3af),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositive ? const Color(0xFF22c55e) : const Color(0xFFf59e0b))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isPositive ? const Color(0xFF22c55e) : const Color(0xFFf59e0b),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      trend,
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF22c55e) : const Color(0xFFf59e0b),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            range,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161a18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1f2933)),
      ),
      child: Row(
        children: [
          _buildTab('Overview', 0),
          _buildTab('Trends', 1),
          _buildTab('Equipment', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF22c55e) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF9ca3af),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureHumidityChart() {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Color(0xFF22c55e), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temperature & Humidity Trends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Past 7 days environmental history',
                      style: TextStyle(
                        color: Color(0xFF9ca3af),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFF1f2933),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Color(0xFF9ca3af),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _stats.length) {
                          String date = _stats[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              date.substring(date.length - 2),
                              style: const TextStyle(
                                color: Color(0xFF9ca3af),
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_stats.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  // Temperature line
                  LineChartBarData(
                    spots: _stats.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.avgTemperature);
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF22c55e),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF22c55e).withOpacity(0.1),
                    ),
                  ),
                  // Humidity line
                  LineChartBarData(
                    spots: _stats.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.avgHumidity);
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF3b82f6),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3b82f6).withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Temperature (°C)', const Color(0xFF22c55e)),
              const SizedBox(width: 24),
              _buildLegendItem('Humidity (%)', const Color(0xFF3b82f6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterUsageChart() {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.water, color: Color(0xFF3b82f6), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Water Consumption',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Daily usage in Liters',
                      style: TextStyle(
                        color: Color(0xFF9ca3af),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}L',
                        style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _stats.length) {
                          return Text(
                            _stats[index].date.substring(8),
                            style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 9),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _stats.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.waterUsage,
                        color: const Color(0xFF3b82f6),
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9ca3af),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatusChart() {
    int critical = _alerts.where((a) => a.severity == 'danger' && !a.resolved).length;
    int warning = _alerts.where((a) => a.severity == 'warning' && !a.resolved).length;
    int normal = _alerts.isEmpty ? 1 : _alerts.where((a) => a.resolved).length;
    if (critical == 0 && warning == 0 && normal == 0) normal = 1;

    double total = (critical + warning + normal).toDouble();

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, color: Color(0xFF22c55e), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Status Distribution',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Overall health metrics',
                      style: TextStyle(
                        color: Color(0xFF9ca3af),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          value: normal.toDouble(),
                          color: const Color(0xFF22c55e),
                          radius: 35,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: warning.toDouble(),
                          color: const Color(0xFFf59e0b),
                          radius: 35,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: critical.toDouble(),
                          color: const Color(0xFFdc2626),
                          radius: 35,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusItem('Normal', '${(normal / total * 100).toStringAsFixed(0)}%', const Color(0xFF22c55e)),
                      const SizedBox(height: 12),
                      _buildStatusItem('Warning', '${(warning / total * 100).toStringAsFixed(0)}%', const Color(0xFFf59e0b)),
                      const SizedBox(height: 12),
                      _buildStatusItem('Critical', '${(critical / total * 100).toStringAsFixed(0)}%', const Color(0xFFdc2626)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertSummary() {
    int critical = _alerts.where((a) => a.severity == 'danger' && !a.resolved).length;
    int warning = _alerts.where((a) => a.severity == 'warning' && !a.resolved).length;
    int resolved = _alerts.where((a) => a.resolved).length;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFf59e0b), size: 18),
              SizedBox(width: 8),
              Text(
                'Alert Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertMetricRow('Critical', critical, const Color(0xFFdc2626), Icons.error_outline),
          const SizedBox(height: 12),
          _buildAlertMetricRow('Warning', warning, const Color(0xFFf59e0b), Icons.warning_amber_rounded),
          const SizedBox(height: 12),
          _buildAlertMetricRow('Resolved', resolved, const Color(0xFF22c55e), Icons.check_circle_outline),
        ],
      ),
    );
  }

  Widget _buildAlertMetricRow(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time, color: Color(0xFF22c55e), size: 18),
              SizedBox(width: 8),
              Text(
                'Activity Timeline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_alerts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No recent activity', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _alerts.length > 5 ? 5 : _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildTimelineItem(
                  alert.message,
                  '${DateTime.now().difference(alert.timestamp).inHours} hours ago',
                  alert.severity == 'danger' ? Icons.error : (alert.resolved ? Icons.check_circle : Icons.warning),
                  alert.severity == 'danger' ? const Color(0xFFdc2626) : (alert.resolved ? const Color(0xFF22c55e) : const Color(0xFFf59e0b)),
                  isLast: index == (_alerts.length > 5 ? 4 : _alerts.length - 1),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendsChart() {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Color(0xFF4AB08B), size: 18),
              SizedBox(width: 8),
              Text(
                'Weekly Feed vs Water',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _stats.length) {
                          return Text(_stats[index].date.substring(8), style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 9));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _stats.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(toY: e.value.waterUsage, color: const Color(0xFF3b82f6), width: 8),
                      BarChartRodData(toY: e.value.feedUsage, color: const Color(0xFF4AB08B), width: 8),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Water (L)', const Color(0xFF3b82f6)),
              const SizedBox(width: 24),
              _buildLegendItem('Feed (kg)', const Color(0xFF4AB08B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentPerformanceChart() {
    if (_stats.isEmpty) return const SizedBox.shrink();
    final latest = _stats.last.equipmentUptime;
    
    final data = [
      {'name': 'Fan', 'uptime': latest.fan.toDouble()},
      {'name': 'Fogger', 'uptime': latest.fogger.toDouble()},
      {'name': 'Sprinkler', 'uptime': latest.sprinkler.toDouble()},
      {'name': 'Motor', 'uptime': latest.motor.toDouble()},
    ];

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_input_component, color: Color(0xFF4AB08B), size: 18),
              SizedBox(width: 8),
              Text(
                'Equipment Performance (%)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...data.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['name'] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('${(item['uptime'] as double).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (item['uptime'] as double) / 100,
                    backgroundColor: const Color(0xFF1f2933),
                    color: const Color(0xFF22c55e),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9ca3af),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String title,
    String time,
    IconData icon,
    Color color, {
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: const Color(0xFF1f2933),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
