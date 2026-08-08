import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 图片工具：选图/拍照 → 复制到应用文档目录 images/，存相对路径
class ImageHelper {
  /// 选择一张图片（相册或拍照），返回相对路径（images/xxx.jpg），取消返回 null
  static Future<String?> pick(BuildContext context,
      {bool allowCamera = true}) async {
    final source = allowCamera
        ? await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('从相册选择'),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('拍照'),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ],
              ),
            ),
          )
        : ImageSource.gallery;
    if (source == null) return null;
    try {
      final xfile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (xfile == null) return null;
      return await saveToApp(xfile.path);
    } catch (_) {
      return null;
    }
  }

  /// 复制图片到应用文档目录 images/，返回相对路径
  static Future<String> saveToApp(String srcPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}images');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ext = srcPath.contains('.')
        ? srcPath.substring(srcPath.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final name = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
    File(srcPath).copySync('${dir.path}${Platform.pathSeparator}$name');
    return 'images/$name';
  }

  /// 相对路径 → 完整路径（由 ItemImage 内部解析）
  static String? resolve(String? relative) {
    return relative;
  }
}

/// 显示一张图：有图显示图片（失败回退占位），无图显示 emoji
class ItemImage extends StatelessWidget {
  const ItemImage({
    super.key,
    required this.imagePath,
    required this.emoji,
    this.size = 56,
    this.borderRadius = 12,
  });

  final String? imagePath;
  final String emoji;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5))),
      );
    }
    return FutureBuilder<File?>(
      future: _fileCache.putIfAbsent(imagePath!, () => _resolveFile(imagePath!)),
      builder: (context, snap) {
        final file = snap.data;
        if (file == null) {
          return SizedBox(
            width: size,
            height: size,
            child: Center(
                child: Text(emoji, style: TextStyle(fontSize: size * 0.5))),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => SizedBox(
              width: size,
              height: size,
              child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: size * 0.5))),
            ),
          ),
        );
      },
    );
  }

  static final Map<String, Future<File?>> _fileCache = {};

  static Future<File?> _resolveFile(String relative) async {
    final docs = await getApplicationDocumentsDirectory();
    final f = File('${docs.path}${Platform.pathSeparator}$relative');
    return f.existsSync() ? f : null;
  }
}
