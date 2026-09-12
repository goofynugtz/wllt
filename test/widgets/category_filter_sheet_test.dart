import 'package:flutter_test/flutter_test.dart';
import 'package:wllt/widgets/category_filter_sheet.dart';

void main() {
  group('CategoryFilterSheet.mergeSelection', () {
    test('preserves other-category ids when current is a non-empty allow-list', () {
      final result = CategoryFilterSheet.mergeSelection(
        current: ['shopping', 'transport', 'savings'],
        selectedExpenseIds: {'shopping'},
        allExpenseIds: {'shopping', 'transport', 'groceries'},
        allOtherIds: {'savings', 'work'},
      );
      expect(result.toSet(), {'shopping', 'savings'});
    });

    test('treats empty current as "all active" and keeps other ids explicit', () {
      final result = CategoryFilterSheet.mergeSelection(
        current: [],
        selectedExpenseIds: {'shopping'},
        allExpenseIds: {'shopping', 'transport', 'groceries'},
        allOtherIds: {'savings', 'work'},
      );
      expect(result.toSet(), {'shopping', 'savings', 'work'});
    });

    test('deselecting all expense categories still leaves a non-empty list', () {
      final result = CategoryFilterSheet.mergeSelection(
        current: ['shopping', 'savings'],
        selectedExpenseIds: {},
        allExpenseIds: {'shopping', 'transport', 'groceries'},
        allOtherIds: {'savings', 'work'},
      );
      expect(result, ['savings']);
    });
  });
}
