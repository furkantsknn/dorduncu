import 'package:flutter/material.dart';

enum SupportCategory {
  suggestion,
  bugReport,
  generalSupport,
  paymentIssue,
  accountAppeal,
  userReport,
  eventReport,
  messageReport,
  inappropriateImage,
  securityEmergency,
}

enum SupportUrgency {
  low,
  normal,
  high,
  critical,
}

enum SupportRequestStatus {
  newRequest,
  reviewing,
  answered,
  closed,
}

extension SupportCategoryExtension on SupportCategory {
  String get value {
    switch (this) {
      case SupportCategory.suggestion:
        return 'suggestion';
      case SupportCategory.bugReport:
        return 'bug_report';
      case SupportCategory.generalSupport:
        return 'general_support';
      case SupportCategory.paymentIssue:
        return 'payment_issue';
      case SupportCategory.accountAppeal:
        return 'account_appeal';
      case SupportCategory.userReport:
        return 'user_report';
      case SupportCategory.eventReport:
        return 'event_report';
      case SupportCategory.messageReport:
        return 'message_report';
      case SupportCategory.inappropriateImage:
        return 'inappropriate_image';
      case SupportCategory.securityEmergency:
        return 'security_emergency';
    }
  }

  String get title {
    switch (this) {
      case SupportCategory.suggestion:
        return 'Öneri gönder';
      case SupportCategory.bugReport:
        return 'Hata bildir';
      case SupportCategory.generalSupport:
        return 'Genel destek talebi';
      case SupportCategory.paymentIssue:
        return 'Ödeme sorunu bildir';
      case SupportCategory.accountAppeal:
        return 'Hesap itirazı';
      case SupportCategory.userReport:
        return 'Kullanıcıyı şikâyet et';
      case SupportCategory.eventReport:
        return 'Etkinliği şikâyet et';
      case SupportCategory.messageReport:
        return 'Mesajı şikâyet et';
      case SupportCategory.inappropriateImage:
        return 'Uygunsuz görsel bildir';
      case SupportCategory.securityEmergency:
        return 'Güvenlik / acil durum bildirimi';
    }
  }

  String get description {
    switch (this) {
      case SupportCategory.suggestion:
        return 'Uygulamayı geliştirmemize yardımcı olacak önerini paylaş.';
      case SupportCategory.bugReport:
        return 'Uygulamada karşılaştığın teknik bir sorunu bildir.';
      case SupportCategory.generalSupport:
        return 'Genel konularda destek ekibinden yardım al.';
      case SupportCategory.paymentIssue:
        return 'Ödeme, ücretlendirme veya abonelik sorununu bildir.';
      case SupportCategory.accountAppeal:
        return 'Hesap kısıtlaması veya hesap işlemi için itiraz oluştur.';
      case SupportCategory.userReport:
        return 'Başka bir kullanıcının davranışını şikâyet et.';
      case SupportCategory.eventReport:
        return 'Bir etkinlikle ilgili kural ihlalini bildir.';
      case SupportCategory.messageReport:
        return 'Uygunsuz, tehditkâr veya istenmeyen bir mesajı bildir.';
      case SupportCategory.inappropriateImage:
        return 'Uygunsuz profil veya etkinlik görselini bildir.';
      case SupportCategory.securityEmergency:
        return 'Güvenlik riski, tehdit veya acil bir durumu bildir.';
    }
  }

  IconData get icon {
    switch (this) {
      case SupportCategory.suggestion:
        return Icons.lightbulb_outline;
      case SupportCategory.bugReport:
        return Icons.bug_report_outlined;
      case SupportCategory.generalSupport:
        return Icons.support_agent_outlined;
      case SupportCategory.paymentIssue:
        return Icons.payment_outlined;
      case SupportCategory.accountAppeal:
        return Icons.gavel_outlined;
      case SupportCategory.userReport:
        return Icons.person_off_outlined;
      case SupportCategory.eventReport:
        return Icons.event_busy_outlined;
      case SupportCategory.messageReport:
        return Icons.mark_chat_unread_outlined;
      case SupportCategory.inappropriateImage:
        return Icons.hide_image_outlined;
      case SupportCategory.securityEmergency:
        return Icons.emergency_outlined;
    }
  }

  bool get requiresRelatedUser {
    return this == SupportCategory.userReport;
  }

  bool get requiresRelatedEvent {
    return this == SupportCategory.eventReport;
  }

  bool get requiresRelatedMessage {
    return this == SupportCategory.messageReport;
  }

  bool get isCriticalCategory {
    return this == SupportCategory.securityEmergency;
  }

  bool get isReportCategory {
    return this == SupportCategory.userReport ||
        this == SupportCategory.eventReport ||
        this == SupportCategory.messageReport ||
        this == SupportCategory.inappropriateImage ||
        this == SupportCategory.securityEmergency;
  }

  static SupportCategory fromValue(String? value) {
    switch (value) {
      case 'suggestion':
        return SupportCategory.suggestion;
      case 'bug_report':
        return SupportCategory.bugReport;
      case 'payment_issue':
        return SupportCategory.paymentIssue;
      case 'account_appeal':
        return SupportCategory.accountAppeal;
      case 'user_report':
      case 'report_user':
        return SupportCategory.userReport;
      case 'event_report':
      case 'report_event':
        return SupportCategory.eventReport;
      case 'message_report':
      case 'report_message':
        return SupportCategory.messageReport;
      case 'inappropriate_image':
      case 'report_image':
        return SupportCategory.inappropriateImage;
      case 'security_emergency':
      case 'security_report':
        return SupportCategory.securityEmergency;
      case 'general_support':
      default:
        return SupportCategory.generalSupport;
    }
  }
}

extension SupportUrgencyExtension on SupportUrgency {
  String get value {
    switch (this) {
      case SupportUrgency.low:
        return 'low';
      case SupportUrgency.normal:
        return 'normal';
      case SupportUrgency.high:
        return 'high';
      case SupportUrgency.critical:
        return 'critical';
    }
  }

  String get title {
    switch (this) {
      case SupportUrgency.low:
        return 'Düşük';
      case SupportUrgency.normal:
        return 'Normal';
      case SupportUrgency.high:
        return 'Yüksek';
      case SupportUrgency.critical:
        return 'Kritik';
    }
  }

  static SupportUrgency fromValue(String? value) {
    switch (value) {
      case 'low':
        return SupportUrgency.low;
      case 'high':
        return SupportUrgency.high;
      case 'critical':
        return SupportUrgency.critical;
      case 'normal':
      default:
        return SupportUrgency.normal;
    }
  }
}

extension SupportRequestStatusExtension on SupportRequestStatus {
  String get value {
    switch (this) {
      case SupportRequestStatus.newRequest:
        return 'new';
      case SupportRequestStatus.reviewing:
        return 'reviewing';
      case SupportRequestStatus.answered:
        return 'answered';
      case SupportRequestStatus.closed:
        return 'closed';
    }
  }

  String get title {
    switch (this) {
      case SupportRequestStatus.newRequest:
        return 'Yeni';
      case SupportRequestStatus.reviewing:
        return 'İnceleniyor';
      case SupportRequestStatus.answered:
        return 'Cevaplandı';
      case SupportRequestStatus.closed:
        return 'Kapatıldı';
    }
  }

  static SupportRequestStatus fromValue(String? value) {
    switch (value) {
      case 'reviewing':
        return SupportRequestStatus.reviewing;
      case 'answered':
        return SupportRequestStatus.answered;
      case 'closed':
        return SupportRequestStatus.closed;
      case 'new':
      default:
        return SupportRequestStatus.newRequest;
    }
  }
}