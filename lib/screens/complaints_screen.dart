import 'package:flutter/material.dart';

import 'support_center_screen.dart';

/// Legacy compatibility entry point.
/// All reports and complaints now use the unified support_requests workflow.
class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SupportCenterScreen();
  }
}
