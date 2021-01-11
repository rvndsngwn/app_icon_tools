import 'dart:async';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/image_resizer.dart';
import 'package:platform_info/platform_info.dart';

import '../constants/default_non_null_values.dart';
import '../constants/issues_levels.dart';
import '../extensions/image_resizer_extensions/android_adaptive.dart';
import '../extensions/image_resizer_extensions/constants/android_regular.dart';
import '../extensions/image_resizer_extensions/constants/macos.dart';
import '../extensions/image_resizer_extensions/constants/web.dart';
import '../extensions/image_resizer_extensions/ios.dart';
import '../extensions/image_resizer_extensions/linux/linux_folder.dart';
import '../extensions/image_resizer_extensions/pwa.dart';
import '../extensions/image_resizer_extensions/windows.dart';
import '../generated/l10n.dart';
import '../locator_di.dart';
import '../services/files_services/file_saver.dart';
import '../services/navigation_service.dart';
import '../services/router.dart';
import 'helpers/export_platforms.dart';

// TODO Reduce this model size.
class SetupIcon extends ChangeNotifier {
  // ! Utils section !
  static const String _foreground = 'foreground', _background = 'background', _info = IssueLevel.info;
  void issuesToClipboard() => Clipboard.setData(ClipboardData(text: issues(toClipboard: true)));

  // ! Navigation section !
  final NavigationService _navigationService = locator<NavigationService>();
  void devicePreview() => _navigationService.navigateTo(UiRouter.deviceScreen);
  void initialScreen() => _navigationService.navigateTo(UiRouter.initialScreen);
  void setupScreen() => _navigationService.navigateTo(UiRouter.setupScreen);
  void goBack() => _navigationService.goBack();

// ! Platforms section !
  int _platformID = 0;
  int get platformID => _platformID;
  void setPlatform(int selectedPlatform) {
    if (selectedPlatform != _platformID) {
      {
        _platformID = selectedPlatform;
        notifyListeners();
      }
    }
  }

  Map<String, bool> get platforms => ExportPlatform.mapEvery;
  void switchPlatform({@required String platformNameKey, @required bool isExported}) {
    _regularIconFiles.clear();
    ExportPlatform.setPlatformToExport(platformNameKey, isExported: isExported);
    notifyListeners();
  }

  // ! Regular (Non-Adaptive-Android) Icon section !
  // Regular (Non-Adaptive-Android) Icon Background Color:
  Color get backgroundColor => _regularBgColor;
  void setBackgroundColor(Color newColor) {
    if (_regularBgColor != newColor) {
      _regularBgColor = newColor;
      if (!haveAdaptiveColor) {
        _adaptiveBgColor = _regularBgColor.withAlpha(255);
      }
      notifyListeners();
    }
  }

  bool get bgColorIsEmpty => backgroundColor == NullSafeValues.noColor;
  void removeColor() {
    _regularBgColor = NullSafeValues.noColor;
    notifyListeners();
  }

// Regular (Non-Adaptive-Android) Icon Image:
  Image get iconImage => Image.memory(_icon);
  Uint8List get regularIcon => _icon;
  set regularIcon(Uint8List uploadedPNG) {
    if (uploadedPNG != _icon && uploadedPNG != NullSafeValues.zeroBytes) {
      _icon = uploadedPNG;
      _wipeOldData();
      notifyListeners();
    }
  }

  void _wipeOldData() {
    _adaptiveBackground = _adaptiveForeground = NullSafeValues.zeroBytes;
    _regularIconFiles.clear();
    _adaptiveIconFiles.clear();
    _pwaConfigs.clear();
    _xmlConfigs.clear();
    _bgIssues.clear();
    _fgIssues.clear();
  }

  Set<String> get iconIssues => _regIconIssues;
  set iconIssues(Set<String> detectedIssues) {
    if (_regIconIssues != detectedIssues) {
      _regIconIssues
        ..clear()
        ..addAll(detectedIssues);
    }
  }

  Color _adaptiveBgColor = NullSafeValues.noColor, _regularBgColor = NullSafeValues.noColor;
  Uint8List _icon = NullSafeValues.zeroBytes,
      _adaptiveBackground = NullSafeValues.zeroBytes,
      _adaptiveForeground = NullSafeValues.zeroBytes;

// ! Android 8+ Icon section !
// Android 8+ Adaptive Icon Background COLOR:
  Color get adaptiveColor => _adaptiveBgColor;
  void setAdaptiveColor(Color newColor) {
    if (_adaptiveBgColor != newColor) {
      _adaptiveBgColor = newColor;
      if (newColor != NullSafeValues.noColor && bgColorIsEmpty) {
        _regularBgColor = _adaptiveBgColor.withAlpha(255);
      }
      notifyListeners();
    }
  }

  void removeAdaptiveColor() {
    _adaptiveBgColor = NullSafeValues.noColor;
    notifyListeners();
  }

  bool _preferColorBg = false;
  bool get haveAdaptiveColor => _adaptiveBgColor != NullSafeValues.noColor;
  bool get preferColorBg => _preferColorBg;
  void switchBgColorPreference({@required bool preferColor}) {
    _preferColorBg = preferColor;
    notifyListeners();
  }

// Android 8+ Adaptive Icon Background IMAGE:
  Uint8List get adaptiveBackground => _adaptiveBackground;
  set adaptiveBackground(Uint8List uploadedPNG) {
    if (uploadedPNG != _adaptiveBackground && uploadedPNG != NullSafeValues.zeroBytes) {
      _adaptiveBackground = uploadedPNG;
      _adaptiveIconFiles.clear();
      notifyListeners();
    }
  }

  bool get haveAdaptiveBackground => _adaptiveBackground != NullSafeValues.zeroBytes;
  void removeAdaptiveBackground() {
    _adaptiveBackground = NullSafeValues.zeroBytes;
    _bgIssues.clear();
    notifyListeners();
  }

// Android 8+ Adaptive Icon Foreground (always as image):
  Uint8List get adaptiveForeground => _adaptiveForeground;
  set adaptiveForeground(Uint8List uploadedPNG) {
    if (uploadedPNG != _adaptiveForeground && uploadedPNG != NullSafeValues.zeroBytes) {
      _adaptiveForeground = uploadedPNG;
      _adaptiveIconFiles.clear();
      notifyListeners();
    }
  }

  bool get haveAdaptiveForeground => _adaptiveForeground != NullSafeValues.zeroBytes;
  void removeadaptiveForeground() {
    _adaptiveForeground = NullSafeValues.zeroBytes;
    _fgIssues.clear();
    notifyListeners();
  }

// Other Android 8+ Adaptive icon setups:
  bool get _exportingAdaptiveFiles =>
      ExportPlatform.androidNew &&
      (haveAdaptiveForeground && ((haveAdaptiveBackground && !preferColorBg) || (haveAdaptiveColor && preferColorBg)));

  Set<String> get foregroundIssues => _fgIssues;
  set foregroundIssues(Set<String> detectedIssues) {
    if (_fgIssues != detectedIssues) {
      _fgIssues
        ..clear()
        ..addAll(detectedIssues);
    }
  }

  Set<String> get backgroundIssues => _bgIssues;
  set backgroundIssues(Set<String> detectedIssues) {
    if (_bgIssues != detectedIssues) {
      _bgIssues
        ..clear()
        ..addAll(detectedIssues);
    }
  }

  // ! All Issues Section !
  final Set<String> _fgIssues = {}, _bgIssues = {}, _regIconIssues = {};

  String issues({bool toClipboard = false}) {
    StringBuffer regularIssuesText = StringBuffer(),
        foregroundIssuesText = StringBuffer(),
        backgroundIssuesText = StringBuffer();
    if (_regIconIssues.isNotEmpty) {
      regularIssuesText = _stringIssues();
    }
    if (_fgIssues.isNotEmpty) {
      foregroundIssuesText = _stringIssues(where: _foreground);
    }
    if (_bgIssues.isNotEmpty) {
      backgroundIssuesText = _stringIssues(where: _background);
    }
    final StringBuffer _issues = regularIssuesText..write(foregroundIssuesText)..write(backgroundIssuesText);
    if (_issues.isNotEmpty && !toClipboard) {
      _issues.write('\n');
      if (platform.isDesktop) {
        _issues
          ..write('\n')
          ..write(S.current.issuesToClipboard)
          ..write('\n')
          ..write(S.current.officialDocs)
          ..write('\n');
      }
    }
    return _issues.toString();
  }

  StringBuffer _stringIssues({String where = 'regularIcon'}) {
    final StringBuffer textInMemory = StringBuffer();
    switch (where) {
      case _background:
        {
          textInMemory..write('\n\n')..write(S.current.adaptiveBackground);
          for (final String issue in _bgIssues) {
            textInMemory..write('\n')..write('$issue ')..write(_translate(issue));
          }
          break;
        }
      case _foreground:
        {
          textInMemory..write('\n\n')..write(S.current.adaptiveForeground);
          for (final String issue in _fgIssues) {
            textInMemory..write('\n')..write('$issue ')..write(_translate(issue));
          }
          if (!_fgIssues.contains(_info) && ExportPlatform.androidNew) {
            textInMemory..write('\n')..write(S.current.transparencyAdaptive);
          }
          break;
        }
      default:
        {
          textInMemory..write('\n\n')..write(S.current.regularIcon);
          for (final String issue in _regIconIssues) {
            textInMemory..write('\n')..write('$issue ')..write(_translate(issue));
          }
          if (_regIconIssues.contains(_info) && (ExportPlatform.iOS || ExportPlatform.pwa)) {
            textInMemory..write('\n')..write(S.current.transparencyIOS);
          }
          break;
        }
    }
    return textInMemory;
  }

  String _translate(String issue) {
    switch (issue) {
      case IssueLevel.alert:
        {
          return S.current.tooSmall;
        }
      case IssueLevel.danger:
        {
          return S.current.tooHeavy;
        }
      case IssueLevel.warning:
        {
          return S.current.notSqaure;
        }
      case IssueLevel.info:
        {
          return S.current.isTransparent;
        }
      default:
        return '';
    }
  }

  double get hue {
    final int iconIssuesCount = _regIconIssues.length - (_regIconIssues.contains(_info) ? 1 : 0);
    final int fgIssuesCount = _fgIssues.length - (_fgIssues.contains(_info) ? 1 : 0);
    final int bgIssuesCount = _bgIssues.length - (_bgIssues.contains(_info) ? 1 : 0);
    return max(0, 70 - (17.5 * iconIssuesCount) - (17.5 * fgIssuesCount) - (17.5 * bgIssuesCount));
  }

  // ! Icon Shape section !
  double _iconShapeRadius = 25;
  double get cornerRadius => _iconShapeRadius;
  void setRadius(double newRadius) {
    if (newRadius != _iconShapeRadius) {
      _iconShapeRadius = newRadius;
      notifyListeners();
    }
  }

  // ! Icons Export and Archive section !
  final Map<String, List<FileData>> _regularIconFiles = {}, _adaptiveIconFiles = {}, _xmlConfigs = {}, _pwaConfigs = {};

  Future archive() async {
    _exportedDoneCount = 0;
    _setLoading(true);

    final IconGenerator genertator = IconGenerator();
    final List<FileData> filesList = [];

    Future<void>.delayed(
        //TODO Move to Isolate, when https://github.com/flutter/flutter/issues/33577 is closed.
        const Duration(milliseconds: kIsWeb ? 300 : 60),
        () async => await _resizeIcons().whenComplete(() async {
              for (final String key in _regularIconFiles.keys) {
                final List<FileData> folderWithIcons = _regularIconFiles[key];
                if (folderWithIcons != null) {
                  filesList.addAll(folderWithIcons.toList());
                }
              }

              if (_exportingAdaptiveFiles && _adaptiveIconFiles.isNotEmpty) {
                for (final String key in _adaptiveIconFiles.keys) {
                  final List<FileData> adaptiveFolder = _adaptiveIconFiles[key];
                  if (adaptiveFolder != null) {
                    filesList.addAll(adaptiveFolder.toList());
                  }
                }
                _generateXmlConfigs();
                for (final String key in _xmlConfigs.keys) {
                  final List<FileData> txtFolder = _xmlConfigs[key];
                  if (txtFolder != null) {
                    filesList.addAll(txtFolder.toList());
                  }
                }
              }

              if (ExportPlatform.pwa) {
                _generatePwaConfigs();
                for (final String key in _pwaConfigs.keys) {
                  final List<FileData> txtFolder = _pwaConfigs[key];
                  if (txtFolder != null) {
                    filesList.addAll(txtFolder.toList());
                  }
                }
              }

              final List<int> archiveFileData = genertator.generateArchive(filesList);
              await saveFile(archiveFileData).then((correctlyExported) {
                _countdown = _exportedDoneCount = 0;
                _loading = false;
                if (correctlyExported) {
                  _showSnackInfo(); // TODO? Show error if archive is used by another process?
                } else {
                  notifyListeners();
                }
              });
            }));
  }

  bool _loading = false;
  int _countdown = 0, _exportedDoneCount = 0;

  int get countdown => _countdown;

  void _showSnackInfo() {
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_countdown > 99) {
        _countdown = 0;
        timer.cancel();
      } else {
        _countdown = _countdown + 1;
      }
      notifyListeners();
    });
  }

  int get _toExportCount => (_exportingAdaptiveFiles ? 2 : 1) + ExportPlatform.count;

  num get exportProgress => 100 * (_exportedDoneCount / _toExportCount).clamp(0, 1);

  bool get loading => _loading;

  void _setLoading(bool isLoading) {
    _loading = isLoading;
    notifyListeners();
  }

  // ! Icons Generate section !
  Future _resizeIcons() async {
    if (_regularIconFiles.isEmpty) {
      if (ExportPlatform.pwa) {
        await _generatePngIcons('web', WebIconsFolder(path: 'web', icons: webIcons));
      }
      if (ExportPlatform.iOS) {
        await _generatePngIcons('iOS', IosIconsFolder(icons: iOsIcons));
      }
      if (ExportPlatform.macOS) {
        await _generatePngIcons('macOS', MacOSIconsFolder(icons: macos));
      }
      if (ExportPlatform.windows) {
        await _generateIcoIcon(WindowsIconsFolder());
      }
      if (ExportPlatform.androidOld) {
        await _generatePngIcons('droid', AndroidIconsFolder(icons: androidRegular));
      }
      if (ExportPlatform.linux) {
        await _generatePngIcons('linux', LinuxIconsFolder());
      }
    } else {
      _exportedDoneCount = _toExportCount - (_exportingAdaptiveFiles ? 3 : 2);
      notifyListeners();
    }
    if (_adaptiveIconFiles.isEmpty) {
      if (_exportingAdaptiveFiles) {
        if (!preferColorBg) {
          await _generateAdaptiveIcons(BackgroundIconsFolder());
        }
        await _generateAdaptiveIcons(ForegroundIconsFolder());
      }
    } else {
      _exportedDoneCount = _toExportCount - 1;
      notifyListeners();
    }
  }

  void _generateXmlConfigs({String key = 'xml'}) {
    final XmlGenerator genertator = XmlGenerator(bgAsColor: preferColorBg, color: _colorForConfigs(isXml: true));
    final List<FileData> xmlsList = genertator.generateXmls();
    _xmlConfigs[key] = xmlsList;
    _exportedDoneCount = _exportedDoneCount + 1;
    notifyListeners();
  }

  Color _colorForConfigs({bool isXml = false}) {
    Color color = bgColorIsEmpty ? const Color(0xFF000000) : backgroundColor;
    if (isXml && haveAdaptiveColor) {
      color = adaptiveColor;
    }
    return color;
  }

  void _generatePwaConfigs({String key = 'pwa'}) {
    final PwaConfigGenerator genertator = PwaConfigGenerator(color: _colorForConfigs());
    final List<FileData> configsList = genertator.generatePwaConfigs();
    _pwaConfigs[key] = configsList;
    _exportedDoneCount = _exportedDoneCount + 1;
    notifyListeners();
  }

  Future _generatePngIcons(String key, ImageFolder folder) async {
    final img.Image uploadedPNG = img.decodePng(_icon);
    final IconGenerator genertator = IconGenerator();
    final List<FileData> regularIconsList =
        await genertator.generateIcons(uploadedPNG, folder, writeToDiskIO: !kIsWeb && platform.isMacOS);
    _regularIconFiles[key] = regularIconsList;
    _exportedDoneCount = _exportedDoneCount + 1;
    notifyListeners();
  }

  Future _generateAdaptiveIcons(ImageFolder folder) async {
    final bool background = folder is BackgroundIconsFolder;
    final String key = background ? 'bg' : 'fg';
    final img.Image uploadedAdaptivePNG = img.decodePng(background ? _adaptiveBackground : _adaptiveForeground);
    final IconGenerator genertator = IconGenerator();
    final List<FileData> adaptiveIconsList =
        await genertator.generateIcons(uploadedAdaptivePNG, folder, writeToDiskIO: !kIsWeb && platform.isMacOS);
    _adaptiveIconFiles[key] = adaptiveIconsList;
    _exportedDoneCount = _exportedDoneCount + 1;
    notifyListeners();
  }

  Future _generateIcoIcon(ImageFolder folder, {String key = 'win'}) async {
    final img.Image uploadedPNG = img.decodePng(_icon);
    final List<FileData> icoList =
        await WindowsIcon.generate(uploadedPNG, folder, writeToDiskIO: !kIsWeb && platform.isMacOS);
    _regularIconFiles[key] = icoList;
    _exportedDoneCount = _exportedDoneCount + 1;
    notifyListeners();
  }
}
