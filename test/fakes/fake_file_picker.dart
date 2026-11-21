import 'package:file_picker/file_picker.dart';

class FakeFilePicker extends FilePickerPlatform {
  FakeFilePicker({this.directoryPath = '/music/hitster'});

  final String? directoryPath;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return directoryPath;
  }
}
