import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pure grid widget — all expression state and logic live in the parent.
class AmountCalculator extends StatelessWidget {
  final void Function(String label) onButtonPressed;
  final VoidCallback onSetPressed;

  const AmountCalculator({
    super.key,
    required this.onButtonPressed,
    required this.onSetPressed,
  });

  static const _kGap = 5.0;

  static const List<List<(String, String)>> _grid = [
    [('AC', 'd'), ('( )', 'd'), ('%', 'd'), ('÷', 'd')],
    [('7', 'l'), ('8', 'l'), ('9', 'l'), ('×', 'd')],
    [('4', 'l'), ('5', 'l'), ('6', 'l'), ('−', 'd')],
    [('1', 'l'), ('2', 'l'), ('3', 'l'), ('+', 'd')],
    [('0', 'l'), ('.', 'l'), ('⌫', 'l'), ('=', 'g')],
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final numBg = cs.surfaceContainerHigh;
    final numFg = cs.onSurface;
    final opBg  = cs.secondaryContainer;
    final opFg  = cs.onSecondaryContainer;

    return Column(
      children: [
        const SizedBox(height: 20),

        // Grid fills remaining height
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final btnSize = (constraints.maxWidth - _kGap * 3) / 4;
              final rawVGap = (constraints.maxHeight - btnSize * 5) / 4;
              final gap = rawVGap.clamp(4.0, _kGap + 2);
              final fontSize = (btnSize * 0.36).clamp(22.0, 36.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: _grid.asMap().entries.map((rowEntry) {
                  final isLastRow = rowEntry.key == _grid.length - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: rowEntry.value.map((entry) {
                          final (label, type) = entry;
                          final bgColor = switch (type) {
                            'g' => cs.primary,
                            'd' => opBg,
                            _ => numBg,
                          };
                          final fgColor = switch (type) {
                            'g' => cs.onPrimary,
                            'd' => opFg,
                            _ => numFg,
                          };
                          return SizedBox(
                            width: btnSize,
                            height: btnSize,
                            child: Material(
                              color: bgColor,
                              shape: const CircleBorder(),
                              elevation: 2,
                              shadowColor: Colors.black26,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onButtonPressed(label);
                                },
                                child: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: label == '.' ? 'Archia' : null,
                                      fontSize: fontSize,
                                      color: fgColor,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (!isLastRow) SizedBox(height: gap),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSetPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Set Amount',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}
