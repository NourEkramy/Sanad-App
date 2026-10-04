import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class PickedFile {
  const PickedFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Platform file access (pick / share). Kept behind an interface so cubits
/// can be tested without plugins.
abstract interface class FileGateway {
  /// Lets the user choose an .xlsx file; null when cancelled.
  Future<PickedFile?> pickExcel();

  /// Opens the share sheet (mobile) or downloads the file (web).
  Future<void> shareFile({required String name, required List<int> bytes});
}

class PlatformFileGateway implements FileGateway {
  const PlatformFileGateway();

  static const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  Future<PickedFile?> pickExcel() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['xlsx']);
    if (file == null) return null;
    return PickedFile(name: file.name, bytes: await file.readAsBytes());
  }

  @override
  Future<void> shareFile({required String name, required List<int> bytes}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: _xlsxMime)],
        fileNameOverrides: [name],
        downloadFallbackEnabled: true,
      ),
    );
  }
}
