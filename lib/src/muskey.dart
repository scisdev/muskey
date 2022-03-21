import 'package:flutter/services.dart'
    show TextEditingValue, TextInputFormatter, TextSelection;
import 'package:flutter/widgets.dart' show StringCharacters;

/// An actually useful pattern matcher and field input formatter for Flutter.
///
/// Muskey is a single-file light library that's shown its usefulness
/// throughout my projects, so I decided to share it with the world.
///
/// Supports unlimited number of masks, smart cursor positioning,
/// and flexible customization.
/// Clean input value and validity are available at any time.
///
/// This formatter is *stateless* by design, so if you want updates on validity,
/// you need to create your own ways of doing that. For example, you can get
/// current formatter info value inside of onChanged callback in your TextField,
/// add a listener on your TextEditingController or any other way.
///
/// ### Usage:
///
/// Create an instance of this class either inside your StatefulWidget, or
/// directly in your [build] method, and place it in [inputFormatters]
/// list of your [TextField]. Provide a non-empty list of masks to work with,
/// customize if needed.
///
/// [MuskeyFormatter.countryPhoneMasks] factory method is just a shortcut
/// for an instance of this formatter to handle about 300 world phone
/// masks on the fly.
class MuskeyFormatter extends TextInputFormatter {
  /// A description of how to handle overflowing values
  ///
  /// If overflowing inputs are allowed (Telegram log-in style):
  /// `+1 (###) ####-###` ----> `+1 (123) 1234-123456789` is allowed;
  /// Also see [OverflowBehavior] for more configuration.
  ///
  /// If overflowing inputs are not allowed:
  /// `+1 (###) ####-###` ----> `+1 (123) 1234-123` is maximum allowed input.
  ///
  /// If overflow is allowed, input will be valid when mask is complete OR overflown.
  /// If overflow is not allowed, input will ONLY be valid when mask is complete.
  ///
  /// Defaults to [OverflowBehavior.onlyDigits].
  late final OverflowBehavior _overflow;

  /// This variable controls whether to allow autofill of predefined characters
  /// inside your [masks] list. Be careful when using it! If you use it, be sure
  /// to provide a sensible list of masks with consistent starting characters,
  /// ideally provide a list consisting of a single mask.
  late final bool _allowAutofill;

  /// A list of masks, sorted on registration. Each char is:
  ///
  /// [*] a decorator, if char is found in _decorators;
  /// [*] a wildcard, if char is found in _wildcards;
  /// [*] a solid input unit, if char is found in neither.
  late final List<String> _masks;

  /// A map of wildcards and their corresponding [Pattern]s.
  /// See also [Defaults] for default sets.
  late final Map<String, Pattern> _wildcards;

  /// A list of decorators, i.e. characters that carry only visual information.
  /// A common case is to show user input with decorators, but handle user-given
  /// data without them. Decorators can be removed with a [_getClean] method.
  ///
  /// See also [Defaults] for default sets.
  late final List<Pattern> _decorators;

  /// A map of transforms to be applied
  late final Map<String, String Function(String)> _transforms;

  /// Current info about mask and its validity.
  /// Mask will be updated even if input is not valid.
  /// When mask is incomplete, valid will always be `false`.
  /// For when valid is `true`, see [_overflow].
  CurrentMaskInfo _info = const CurrentMaskInfo(
    clean: '',
    isValid: false,
  );
  CurrentMaskInfo get info => _info;

  /// Convenience factory for nice formatting of about 300 phone masks.
  factory MuskeyFormatter.countryPhoneMasks({
    bool allowOverflowingInputs = true,
  }) {
    return MuskeyFormatter(
      masks: Defaults.countryPhoneMasks,
      overflow: OverflowBehavior(
        allowed: allowOverflowingInputs,
        overflowOn: RegExp('[0-9]'),
      ),
      allowAutofill: false,
    );
  }

  MuskeyFormatter({
    required List<String> masks,
    Map<String, Pattern>? wildcards,
    List<Pattern>? decorators,
    Map<String, String Function(String)>? charTransforms,
    OverflowBehavior? overflow,
    bool allowAutofill = false,
  }) {
    _wildcards = wildcards ?? Defaults._wildcardDefaultSet;
    _decorators = decorators ?? Defaults._decoratorDefaultSet;
    _transforms = charTransforms ?? {};
    _overflow = overflow ?? OverflowBehavior.onlyDigits();
    _allowAutofill = allowAutofill;
    _masks = _registerMasks(masks);
  }

  List<String> _registerMasks(List<String> masks) {
    assert(masks.isNotEmpty, '`masks` must not be empty.');

    return List.from(masks, growable: false)
      ..sort((a, b) {
        return a.length.compareTo(b.length);
      });
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldNumDecs = _numDecorators(oldValue.text);
    final newNumDecs = _numDecorators(newValue.text);

    if (!oldValue.selection.isCollapsed) {
      // if we first selected a region.
      // Don't bother and just do a clean cycle.
      return _default(oldValue, newValue);
    }

    if (newValue.text.length == oldValue.text.length - 1) {
      // Removed a single character.
      // An extra check for input prettiness.
      // For instance, when pressing `delete` on web version
      if (newNumDecs == newValue.text.length) {
        // If only decorators are left, just accept the input for ux purposes.
        _info = const CurrentMaskInfo(clean: '', isValid: false);
        return newValue;
      } else {
        return _default(oldValue, newValue);
      }
    }

    if (oldValue.text.length - oldNumDecs ==
        newValue.text.length - newNumDecs) {
      //added or deleted a decorator
      if (newValue.text.length == oldValue.text.length + 1) {
        return _addedDecorator(
          oldValue,
          newValue,
        );
      } else if (newValue.text.length == oldValue.text.length - 1) {
        return _removedDecorator(
          oldValue,
          newValue,
        );
      }
    }

    return _default(oldValue, newValue);
  }

  TextEditingValue _addedDecorator(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newMask = _charByCharSearch(newValue.text);
    final cursor = newValue.selection.baseOffset;
    if (cursor == newValue.text.length) {
      // We added a decorator to the end of input
      if (newMask == null) {
        return oldValue;
      }

      if (newMask.length > cursor - 1 &&
          newMask[cursor - 1] == newValue.text[cursor - 1]) {
        return newValue;
      } else {
        return oldValue;
      }
    } else {
      // We inserted a decorator to `not end` of existing input.
      // Move cursor to the next non-decorator.
      return _moveToNextNonDecorator(
        oldValue,
        newValue,
        cursor,
      );
    }
  }

  TextEditingValue _removedDecorator(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == oldValue.selection.baseOffset) {
      // web: pressed `delete` button.
      // Exceptional case: move cursor _forward_
      return _jumpDecoratorsRight(
        oldValue,
        newValue,
        oldValue.selection.baseOffset,
      );
    }

    // We removed decorator somewhere in the middle.
    // Move cursor to previous non-decorator or 0.
    return _moveToPreviousNonDecorator(
      oldValue,
      newValue,
      newValue.selection.baseOffset,
    );
  }

  TextEditingValue _default(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = _getClean(newValue.text);
    final mask = _findMask(clean);
    if (mask == null) {
      return oldValue;
    }

    final newText = _buildMask(clean, mask);
    _info = CurrentMaskInfo(
      clean: clean,
      isValid: clean.length >= _getClean(mask).length,
    );
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _calculateNewCursor(
          newValue.text,
          newValue.selection.baseOffset,
          newText,
          skip: newText.length -
              _numDecorators(newText) -
              newValue.text.length +
              _numDecorators(newValue.text),
        ),
      ),
    );
  }

  String? _charByCharSearch(String pattern) {
    outer:
    for (final mask in _masks) {
      for (int i = 0; i < pattern.length; i++) {
        if (i > mask.length - 1) {
          if (_overflow.allowed) {
            return mask;
          } else {
            continue outer;
          }
        }

        if (_isDecorator(mask[i]) && mask[i] == pattern[i]) {
          continue;
        }

        if (_wildcards.containsKey(mask[i]) &&
            pattern[i].contains(_wildcards[mask[i]]!)) {
          continue;
        }

        if (mask[i] == pattern[i]) {
          continue;
        }

        continue outer;
      }
      return mask;
    }
    return null;
  }

  String? _findMask(String clean) {
    String? overflowCandidate;
    int checkOverflowFrom = -1;

    outer:
    for (final mask in _masks) {
      int mi = 0;
      int ci = 0;
      while (true) {
        if (ci >= clean.length) {
          return mask;
        }
        if (mi >= mask.length) {
          if (_overflow.allowed) {
            overflowCandidate = mask;
            checkOverflowFrom = ci;
          }
          continue outer;
        }
        if (_isDecorator(mask[mi])) {
          mi++;
          continue;
        }
        if (_wildcards.containsKey(mask[mi])) {
          if (clean[ci++].contains(_wildcards[mask[mi++]]!)) {
            continue;
          } else {
            continue outer;
          }
        } else {
          if (clean[ci] == mask[mi++]) {
            ci++;
            continue;
          } else {
            if (_allowAutofill) {
              continue;
            } else {
              continue outer;
            }
          }
        }
      }
    }
    if (overflowCandidate != null) {
      while (true) {
        if (checkOverflowFrom == clean.length) {
          return overflowCandidate;
        }
        if (!clean[checkOverflowFrom++].contains(
          _overflow.overflowOn!,
        )) {
          return null;
        }
      }
    } else {
      return null;
    }
  }

  // template is guaranteed to fit
  String _buildMask(String pattern, String template) {
    final sb = StringBuffer();
    int pi = 0, ti = 0;
    while (true) {
      if (ti >= template.length) {
        while (pi < pattern.length) {
          sb.write(pattern[pi]);
          pi++;
        }
      }
      if (pi >= pattern.length) {
        return sb.toString();
      }

      if (_isDecorator(template[ti])) {
        sb.write(template[ti++]);
      } else {
        if (_wildcards.containsKey(template[ti])) {
          sb.write(_transformed(template[ti++], pattern[pi++]));
        } else {
          if (template[ti] == pattern[pi]) {
            sb.write(_transformed(template[ti++], pattern[pi++]));
          } else {
            while (true) {
              if (ti >= template.length) {
                break;
              }

              if (!_wildcards.containsKey(template[ti])) {
                sb.write(template[ti++]);
              } else {
                break;
              }
            }
          }
        }
      }
    }
  }

  // Removes decorators from orig
  String _getClean(String orig) {
    final sb = StringBuffer();

    for (final char in orig.characters) {
      if (!_isDecorator(char)) {
        sb.write(char);
      }
    }
    return sb.toString();
  }

  int _numDecorators(String orig) {
    int res = 0;
    for (final char in orig.characters) {
      if (_isDecorator(char)) {
        res++;
      }
    }
    return res;
  }

  bool _isDecorator(String char) {
    for (final dec in _decorators) {
      if (char.contains(dec)) {
        return true;
      }
    }
    return false;
  }

  String _transformed(String char, String actual) {
    return _transforms[char]?.call(actual) ?? actual;
  }

  TextEditingValue _moveToNextNonDecorator(
    TextEditingValue oldValue,
    TextEditingValue newValue,
    int initPos,
  ) {
    int count = 0;
    while (oldValue.text.length > initPos + count &&
        _isDecorator(oldValue.text[initPos + count])) {
      count++;
    }

    return TextEditingValue(
      text: oldValue.text,
      selection: TextSelection.collapsed(
        offset: oldValue.selection.baseOffset + count + 1,
      ),
    );
  }

  TextEditingValue _moveToPreviousNonDecorator(
    TextEditingValue oldValue,
    TextEditingValue newValue,
    int initPos,
  ) {
    int count = 1;
    while (true) {
      if (initPos - count < 0) {
        break;
      } else if (_isDecorator(oldValue.text[initPos - count])) {
        count++;
      } else {
        break;
      }
    }

    return TextEditingValue(
      text: oldValue.text,
      selection: TextSelection.collapsed(
        offset: initPos - count + 1,
      ),
    );
  }

  TextEditingValue _jumpDecoratorsRight(
    TextEditingValue oldValue,
    TextEditingValue newValue,
    int initPos,
  ) {
    int count = 0;

    while (true) {
      final charPos = initPos + count;
      if (oldValue.text.length <= charPos) {
        break;
      }

      if (_isDecorator(oldValue.text[charPos])) {
        count++;
        continue;
      } else {
        break;
      }
    }

    return TextEditingValue(
      text: oldValue.text,
      selection: TextSelection.collapsed(
        offset: oldValue.selection.baseOffset + count,
      ),
    );
  }

  // This calculates new cursor position by counting how many non-decorators
  // were to the left of the old cursor and moves the current cursor to
  // `number of non-decorators in new` + skip
  int _calculateNewCursor(
    String oldText,
    int oldCursor,
    String newText, {
    int skip = 0,
  }) {
    if (oldCursor < 0) return 0;

    int old = skip;
    for (final char in oldText.substring(0, oldCursor).characters) {
      if (!_isDecorator(char)) {
        old++;
      }
    }
    if (old == 0) {
      return 0;
    }

    int numbers = 0;
    int index = 0;
    for (var char in newText.characters) {
      if (!_isDecorator(char)) {
        numbers++;
      }
      if (numbers == old) return index + 1;
      index++;
    }

    return newText.characters.length;
  }

  /// A convenience function to call to autofill fields.
  /// Possible example:
  ///
  /// ``` dart
  /// final _muskeyFormatter = MuskeyFormatter(masks: [...]);
  /// final _phoneController = TextEditingController();
  ///
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   _phoneController.text = _muskeyFormatter.prettyText(myBloc.user.phone);
  /// }
  /// ```
  ///
  /// If no mask was found, will still produce result. In this case,
  /// the result will be equal to [input].
  String prettyText(String input) {
    return formatEditUpdate(
      TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(
          offset: input.length,
        ),
      ),
      TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(
          offset: input.length,
        ),
      ),
    ).text;
  }
}

/// A description of how to handle overflowing values.
/// [overflowOn] describes which values are allowed as overflown.
/// If [allowed], then [overflowOn] must not be null.
class OverflowBehavior {
  final bool allowed;
  final Pattern? overflowOn;

  const OverflowBehavior({
    required this.allowed,
    this.overflowOn,
  }) : assert(
          (allowed && overflowOn != null) || !allowed,
          'If overflow is allowed, `pattern` must not be null.',
        );

  factory OverflowBehavior.onlyDigits() {
    return OverflowBehavior(
      allowed: true,
      overflowOn: RegExp('[0-9]'),
    );
  }

  factory OverflowBehavior.forbidden() {
    return const OverflowBehavior(
      allowed: false,
    );
  }
}

/// Current mask inside [MuskeyFormatter].
class CurrentMaskInfo {
  final String clean;
  final bool isValid;

  const CurrentMaskInfo({
    required this.clean,
    required this.isValid,
  });
}

class Defaults {
  /// A default wildcard set
  static Map<String, Pattern> get _wildcardDefaultSet {
    return {
      '#': RegExp(r'[0-9]'),
      '@': RegExp(r'[a-zA-Z]'),
    };
  }

  /// A default decorator set
  static List<String> get _decoratorDefaultSet {
    return const [' ', '(', ')', '-', '+', '|', '/', ':'];
  }

  /// I realise that the main usage of this library is to do input masks for
  /// registration/login. Therefore, this library comes fitted with a list of
  /// about 300 masks to use and a factory method to easily create
  /// a formatter suited for this.
  ///
  /// The list itself is a slightly modified version of the list found at
  /// https://gist.github.com/mikemunsie/d58d88cad0281e4b187b0effced769b2.
  /// Thank you, mikemunsie c:
  static get countryPhoneMasks => const <String>[
        "+247-####",
        "+376-###-###",
        "+971-5#-###-####",
        "+971-#-###-####",
        "+93-##-###-####",
        "+355 (###) ###-###",
        "+374-##-###-###",
        "+599-###-####",
        "+599-9###-####",
        "+244 (###) ###-###",
        "+672-1##-###",
        "+54 (###) ###-####",
        "+43 (###) ###-####",
        "+61-#-####-####",
        "+297-###-####",
        "+994-##-###-##-##",
        "+387-##-#####",
        "+387-##-####",
        "+880-##-###-###",
        "+32 (###) ###-###",
        "+226-##-##-####",
        "+359 (###) ###-###",
        "+973-####-####",
        "+257-##-##-####",
        "+229-##-##-####",
        "+673-###-####",
        "+591-#-###-####",
        "+55 (##) ####-####",
        "+55 (##) 9####-####",
        "+975-17-###-###",
        "+975-#-###-###",
        "+267-##-###-###",
        "+375 (##) ###-##-##",
        "+501-###-####",
        "+243 (###) ###-###",
        "+236-##-##-####",
        "+242-##-###-####",
        "+41-##-###-####",
        "+225-##-###-###",
        "+682-##-###",
        "+56-#-####-####",
        "+237-####-####",
        "+86 (###) ####-####",
        "+86 (###) ####-###",
        "+86-##-#####-#####",
        "+57 (###) ###-####",
        "+506-####-####",
        "+53-#-###-####",
        "+238 (###) ##-##",
        "+599-###-####",
        "+357-##-###-###",
        "+420 (###) ###-###",
        "+49 (####) ###-####",
        "+49 (###) ###-####",
        "+49 (###) ##-####",
        "+49 (###) ##-###",
        "+49 (###) ##-##",
        "+49-###-###",
        "+253-##-##-##-##",
        "+45-##-##-##-##",
        "+213-##-###-####",
        "+593-##-###-####",
        "+593-#-###-####",
        "+372-####-####",
        "+372-###-####",
        "+20 (###) ###-####",
        "+291-#-###-###",
        "+34 (###) ###-###",
        "+251-##-###-####",
        "+358 (###) ###-##-##",
        "+679-##-#####",
        "+500-#####",
        "+691-###-####",
        "+298-###-###",
        "+262-#####-####",
        "+33 (###) ###-###",
        "+508-##-####",
        "+590 (###) ###-###",
        "+241-#-##-##-##",
        "+995 (###) ###-###",
        "+594-#####-####",
        "+233 (###) ###-###",
        "+350-###-#####",
        "+299-##-##-##",
        "+220 (###) ##-##",
        "+224-##-###-###",
        "+240-##-###-####",
        "+30 (###) ###-####",
        "+502-#-###-####",
        "+245-#-######",
        "+592-###-####",
        "+852-####-####",
        "+504-####-####",
        "+385-##-###-###",
        "+509-##-##-####",
        "+36 (###) ###-###",
        "+62 (8##) ###-####",
        "+62-##-###-##",
        "+62-##-###-###",
        "+62-##-###-####",
        "+62 (8##) ###-###",
        "+62 (8##) ###-##-###",
        "+353 (###) ###-###",
        "+972-5#-###-####",
        "+972-#-###-####",
        "+91 (####) ###-###",
        "+246-###-####",
        "+964 (###) ###-####",
        "+98 (###) ###-####",
        "+354-###-####",
        "+39 (###) ####-###",
        "+962-#-####-####",
        "+81-##-####-####",
        "+81 (###) ###-###",
        "+254-###-######",
        "+996 (###) ###-###",
        "+855-##-###-###",
        "+686-##-###",
        "+269-##-#####",
        "+850-191-###-####",
        "+850-##-###-###",
        "+850-###-####-###",
        "+850-###-###",
        "+850-####-####",
        "+850-####-#############",
        "+82-##-###-####",
        "+965-####-####",
        "+7 (6##) ###-##-##",
        "+7 (7##) ###-##-##",
        "+856 (20##) ###-###",
        "+856-##-###-###",
        "+961-##-###-###",
        "+961-#-###-###",
        "+423 (###) ###-####",
        "+94-##-###-####",
        "+231-##-###-###",
        "+266-#-###-####",
        "+370 (###) ##-###",
        "+352 (###) ###-###",
        "+371-##-###-###",
        "+218-##-###-###",
        "+218-21-###-####",
        "+212-##-####-###",
        "+377 (###) ###-###",
        "+377-##-###-###",
        "+373-####-####",
        "+382-##-###-###",
        "+261-##-##-#####",
        "+692-###-####",
        "+389-##-###-###",
        "+223-##-##-####",
        "+95-##-###-###",
        "+95-#-###-###",
        "+95-###-###",
        "+976-##-##-####",
        "+853-####-####",
        "+596 (###) ##-##-##",
        "+222-##-##-####",
        "+356-####-####",
        "+230-###-####",
        "+960-###-####",
        "+265-1-###-###",
        "+265-#-####-####",
        "+52 (###) ###-####",
        "+52-##-##-####",
        "+60-##-###-####",
        "+60 (###) ###-###",
        "+60-##-###-###",
        "+60-#-###-###",
        "+258-##-###-###",
        "+264-##-###-####",
        "+687-##-####",
        "+227-##-##-####",
        "+672-3##-###",
        "+234 (###) ###-####",
        "+234-##-###-###",
        "+234-##-###-##",
        "+234 (###) ###-####",
        "+505-####-####",
        "+31-##-###-####",
        "+47 (###) ##-###",
        "+977-##-###-###",
        "+674-###-####",
        "+683-####",
        "+64 (###) ###-###",
        "+64-##-###-###",
        "+64 (###) ###-####",
        "+968-##-###-###",
        "+507-###-####",
        "+51 (###) ###-###",
        "+689-##-##-##",
        "+675 (###) ##-###",
        "+63 (###) ###-####",
        "+92 (###) ###-####",
        "+48 (###) ###-###",
        "+970-##-###-####",
        "+351-##-###-####",
        "+680-###-####",
        "+595 (###) ###-###",
        "+974-####-####",
        "+262-#####-####",
        "+40-##-###-####",
        "+381-##-###-####",
        "+7 (###) ###-##-##",
        "+250 (###) ###-###",
        "+966-5-####-####",
        "+966-#-###-####",
        "+677-###-####",
        "+677-#####",
        "+248-#-###-###",
        "+249-##-###-####",
        "+46-##-###-####",
        "+65-####-####",
        "+290-####",
        "+386-##-###-###",
        "+421 (###) ###-###",
        "+232-##-######",
        "+378-####-######",
        "+221-##-###-####",
        "+252-##-###-###",
        "+252-#-###-###",
        "+597-###-####",
        "+597-###-###",
        "+211-##-###-####",
        "+239-##-#####",
        "+503-##-##-####",
        "+963-##-####-###",
        "+268-##-##-####",
        "+235-##-##-##-##",
        "+228-##-###-###",
        "+66-##-###-####",
        "+66-##-###-###",
        "+992-##-###-####",
        "+690-####",
        "+670-###-####",
        "+670-77#-#####",
        "+670-78#-#####",
        "+993-#-###-####",
        "+216-##-###-###",
        "+676-#####",
        "+90 (###) ###-####",
        "+688-90####",
        "+688-2####",
        "+886-#-####-####",
        "+886-####-####",
        "+255-##-###-####",
        "+380 (##) ###-##-##",
        "+256 (###) ###-###",
        "+44-##-####-####",
        "+1 (###) ###-####",
        "+598-#-###-##-##",
        "+998-##-###-####",
        "+39-6-698-#####",
        "+58 (###) ###-####",
        "+84-##-####-###",
        "+84 (###) ####-###",
        "+678-##-#####",
        "+678-#####",
        "+681-##-####",
        "+685-##-####",
        "+967-###-###-###",
        "+967-#-###-###",
        "+967-##-###-###",
        "+27-##-###-####",
        "+260-##-###-####",
        "+263-#-######"
      ];
}
