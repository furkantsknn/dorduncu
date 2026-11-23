import 'package:dorduncu/admin/admin_review_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final records = <Map<String, dynamic>>[
    <String, dynamic>{'status': 'new', 'category': 'general_support'},
    <String, dynamic>{'status': 'new', 'category': 'user_report'},
    <String, dynamic>{'status': 'reviewing', 'category': 'payment_issue'},
  ];

  test('support counters exclude report records', () {
    expect(
      adminReviewStatusCount(
        records,
        scope: AdminReviewScope.support,
        status: 'new',
      ),
      1,
    );
  });

  test('report counters include only report records', () {
    expect(
      adminReviewStatusCount(
        records,
        scope: AdminReviewScope.reports,
        status: 'new',
      ),
      1,
    );
    expect(
      adminReviewMatchesScope(records[0], AdminReviewScope.reports),
      false,
    );
    expect(
      adminReviewMatchesScope(records[1], AdminReviewScope.support),
      false,
    );
  });
}
