import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/language.dart';
import 'contact_models.dart';

/// 联系方式交互：拨号 / 发邮件 / 复制
class ContactActions {
  static Future<void> perform(BuildContext context, ContactMethod m) async {
    switch (m.type) {
      case ContactType.phone:
        final uri = Uri(scheme: 'tel', path: m.value);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (!context.mounted) return;
          _toast(context, t('无法拨号', 'Unable to dial'));
        }
      case ContactType.email:
        final uri = Uri(scheme: 'mailto', path: m.value);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (!context.mounted) return;
          _toast(context, t('无法打开邮件应用', 'Unable to open email app'));
        }
      case ContactType.wechat:
      case ContactType.qq:
      case ContactType.other:
        await Clipboard.setData(ClipboardData(text: m.value));
        if (!context.mounted) return;
        _toast(context, t('已复制 ${m.type.label}：${m.value}', 'Copied ${m.type.label}: ${m.value}'));
    }
  }

  static void _toast(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}
