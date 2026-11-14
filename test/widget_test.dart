import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadu_mobile/src/features/cases/case_entry_screen.dart';

void main() {
  testWidgets('case form uses existing Nadu typing labels', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CaseEntryScreen(companyId: 7)),
      ),
    );

    expect(find.text('නඩු'), findsOneWidget);
    expect(find.text('නඩු අංකය'), findsOneWidget);
    expect(find.text('ණයකරු 1'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('ඇපකරු 2'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('ඇපකරු 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('මූල්‍ය විස්තර'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('මූල්‍ය විස්තර'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Submit case'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Submit case'), findsOneWidget);
  });
}
