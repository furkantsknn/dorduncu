enum AdminReviewScope { all, support, reports }

const Set<String> adminReportCategories = <String>{
  'user_report',
  'event_report',
  'message_report',
  'inappropriate_image',
};

bool isAdminReportCategory(Object? category) {
  return adminReportCategories.contains(category?.toString());
}

AdminReviewScope adminReviewScopeFromFilter(String value) {
  return switch (value) {
    'support' => AdminReviewScope.support,
    'reports' => AdminReviewScope.reports,
    _ => AdminReviewScope.all,
  };
}

bool adminReviewMatchesScope(
  Map<String, dynamic> data,
  AdminReviewScope scope,
) {
  final report = isAdminReportCategory(data['category']);
  return switch (scope) {
    AdminReviewScope.all => true,
    AdminReviewScope.support => !report,
    AdminReviewScope.reports => report,
  };
}

int adminReviewStatusCount(
  Iterable<Map<String, dynamic>> records, {
  required AdminReviewScope scope,
  required String status,
}) {
  return records.where((data) {
    final recordStatus = data['status']?.toString() ?? 'new';
    return recordStatus == status && adminReviewMatchesScope(data, scope);
  }).length;
}
