import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'language.dart';

/// 爱发电主页（上架版打赏入口）
const aifadianUrl = 'https://www.ifdian.net/a/dianranqian13579';

/// 打赏入口是否可用：上架版（release）隐藏微信收款码
bool get donationEnabled => !kReleaseMode;

/// 打开爱发电主页（上架版入口）
Future<void> openAifadian() async {
  final url = Uri.parse(aifadianUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

/// 赛博乞讨：微信收款码打赏弹窗（调试版，供主框架与各子应用复用）
void showDonationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.favorite, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(t('赛博乞讨')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t('来都来了，不赏两个？♥')),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/wechat_qr.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 4),
                      Text(t('请放置收款码'),
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(t('微信扫码支持，金额随意'),
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('关闭'))),
      ],
    ),
  );
}
