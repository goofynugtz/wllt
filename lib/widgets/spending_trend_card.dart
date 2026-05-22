import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class SpendingTrendCard extends StatefulWidget {
  final String title;
  final List<({String label, double amount})> bars;
  final List<String> rangeLabels;
  final int selectedRangeIndex;
  final ValueChanged<int> onRangeChanged;
  final int highlightIndex;
  final Color? accentColor;
  final String currencySymbol;
  final bool showMinMax;
  final double chartHeight;
  final int labelStep;

  const SpendingTrendCard({
    super.key,
    this.title = 'Spending Trend',
    required this.bars,
    required this.rangeLabels,
    required this.selectedRangeIndex,
    required this.onRangeChanged,
    this.highlightIndex = -1,
    this.accentColor,
    required this.currencySymbol,
    this.showMinMax = false,
    this.chartHeight = 120,
    this.labelStep = 1,
  });

  @override
  State<SpendingTrendCard> createState() => _SpendingTrendCardState();
}

class _SpendingTrendCardState extends State<SpendingTrendCard> {
  int _touchedIndex = -1;

  Color _barColor(int index, Color baseColor) {
    if (_touchedIndex >= 0) {
      if (index == _touchedIndex) return baseColor;
      final hsl = HSLColor.fromColor(baseColor);
      return hsl
          .withSaturation(hsl.saturation * 0.25)
          .withLightness(hsl.lightness * 0.55)
          .toColor();
    }
    final isHighlighted =
        widget.highlightIndex < 0 || index == widget.highlightIndex;
    return isHighlighted ? baseColor : baseColor.withValues(alpha: 0.45);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.accentColor ?? AppTheme.primaryColor;
    final maxVal = widget.bars.isEmpty
        ? 0.0
        : widget.bars
            .map((b) => b.amount)
            .reduce((a, b) => a > b ? a : b);
    final positives = widget.bars.where((b) => b.amount > 0);
    final minVal = positives.isEmpty
        ? 0.0
        : positives.map((b) => b.amount).reduce((a, b) => a < b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title,
                  style: TextStyle(fontSize: 13, color: cs.onSurface)),
              Row(
                children: widget.rangeLabels.asMap().entries.map((e) {
                  return _TrendRangePill(
                    label: e.value,
                    selected: e.key == widget.selectedRangeIndex,
                    onTap: () => widget.onRangeChanged(e.key),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final n = widget.bars.length;
              const gap = 4.0;
              final barWidth = n > 1
                  ? (constraints.maxWidth - gap * (n - 1)) / n
                  : constraints.maxWidth;
              return SizedBox(
                height: widget.chartHeight,
                child: BarChart(
                  BarChartData(
                    maxY: maxVal > 0 ? maxVal * 1.2 : 100,
                    barGroups: widget.bars.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.amount,
                            color: _barColor(e.key, color),
                            width: barWidth,
                            borderRadius: BorderRadius.circular(
                              barWidth > 6 ? 4 : 2,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
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
                            final i = value.toInt();
                            if (i < 0 || i >= widget.bars.length) {
                              return const SizedBox.shrink();
                            }
                            if (widget.labelStep > 1 &&
                                i % widget.labelStep != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                widget.bars[i].label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (event is FlTapUpEvent ||
                              event is FlPanEndEvent ||
                              event is FlLongPressEnd ||
                              event is FlPointerExitEvent) {
                            _touchedIndex = -1;
                          } else {
                            _touchedIndex =
                                response?.spot?.touchedBarGroupIndex ?? -1;
                          }
                        });
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => cs.inverseSurface,
                        tooltipRoundedRadius: 6,
                        tooltipPadding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                          Helpers.formatAmount(rod.toY, widget.currencySymbol),
                          TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onInverseSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.showMinMax) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Low ${widget.currencySymbol}${minVal.toStringAsFixed(0)}',
                  style:
                      TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
                Text(
                  'High ${widget.currencySymbol}${maxVal.toStringAsFixed(0)}',
                  style:
                      TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendRangePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TrendRangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 0.8 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
