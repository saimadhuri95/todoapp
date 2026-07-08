import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/order_key.dart';

void main() {
  test('orderKeyBetween creates keys inside open gaps', () {
    final middle = orderKeyBetween(null, null);
    final before = orderKeyBetween(null, middle);
    final after = orderKeyBetween(middle, null);

    expect(before.compareTo(middle), lessThan(0));
    expect(after.compareTo(middle), greaterThan(0));

    final tighter = orderKeyBetween(before, middle);
    expect(tighter.compareTo(before), greaterThan(0));
    expect(tighter.compareTo(middle), lessThan(0));
  });

  test('spacedOrderKey leaves deterministic sortable gaps', () {
    final keys = [for (var i = 0; i < 5; i++) spacedOrderKey(i)];
    expect([...keys]..sort(), keys);
    expect(keys.toSet(), hasLength(keys.length));

    final inserted = orderKeyBetween(keys[1], keys[2]);
    expect(inserted.compareTo(keys[1]), greaterThan(0));
    expect(inserted.compareTo(keys[2]), lessThan(0));
  });

  test('equal concurrent gap choices still sort by stable row id', () {
    final keyA = orderKeyBetween('A', 'B');
    final keyB = orderKeyBetween('A', 'B');

    final rows = [(key: keyB, id: 'row-b'), (key: keyA, id: 'row-a')]
      ..sort((a, b) {
        final byKey = a.key.compareTo(b.key);
        return byKey == 0 ? a.id.compareTo(b.id) : byKey;
      });

    expect(rows.map((row) => row.id), ['row-a', 'row-b']);
  });
}
