import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:muskey/muskey.dart';

void main() {
  formattingChecks();
  validationChecks();
  customDecoratorChecks();
  customWildcardChecks();
  autocompleteChecks();
}

void formattingChecks() {
  group('Inserting data into a field. Formatting.', () {
    test('Inserting correct data.', () {
      final muskey = MuskeyFormatter(
        masks: ['+1 (###) ####-###'],
      );
      const input = '+12345678901';
      expect(muskey.prettyText(input), '+1 (234) 5678-901');
    });
    test('Inserting unformattable data.', () {
      final muskey = MuskeyFormatter(
        masks: ['+1 (567) ####-###'],
      );
      const input = '+12345678901';
      expect(muskey.prettyText(input), input);
    });
    test('Inserting correct overflown data.', () {
      final muskey = MuskeyFormatter(
        masks: ['+1 (###) ####-###'],
      );
      const input = '+12345678901234567890';
      expect(muskey.prettyText(input), '+1 (234) 5678-901234567890');
    });
    test('Inserting correct overflown data, but overflow is prohibited.', () {
      final muskey = MuskeyFormatter(
        masks: ['+1 (###) ####-###'],
        overflow: const OverflowBehavior(allowed: false),
      );
      const input = '+12345678901234567890';
      expect(muskey.prettyText(input), input);
    });
    test('Inserting correct overflown data, should format longest mask.', () {
      final muskey = MuskeyFormatter(
        masks: [
          '+1 (###) ####-###',
          '+1 (###) ####-###-#####-#',
          '+1 (###) ####-###-#####-#-#',
        ],
      );
      const input = '+12345678901234567890';
      expect(muskey.prettyText(input), '+1 (234) 5678-901-23456-7-890');
    });
    test('Prefer shortest mask by full length if non-decorators are equal', () {
      final muskey = MuskeyFormatter(
        masks: [
          '+1 (###) (####)-((###))',
          '+1 (###) ####-###',
        ],
      );
      const input = '+12345678901';
      expect(muskey.prettyText(input), '+1 (234) 5678-901');
    });
  });
}

void validationChecks() {
  group('Valid checks', () {
    test('A simple functionality test', () {
      final muskey = MuskeyFormatter(
        masks: ['+1 (###) ####-###'],
      );
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '+',
        selection: TextSelection.collapsed(
          offset: 1,
        ),
      );
      final res = muskey.formatEditUpdate(oldValue, newValue);
      expect(res.text, '+');
      expect(muskey.info.isValid, false);
    });

    test('A simple functionality test for impossible values', () {
      final muskey = MuskeyFormatter(
        masks: ['+1 (###) ####-###'],
      );
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '-',
        selection: TextSelection.collapsed(
          offset: 1,
        ),
      );
      final res = muskey.formatEditUpdate(oldValue, newValue);
      expect(res.text, '');
      expect(muskey.info.isValid, false);
    });

    test('Main functionality tests', () {
      final muskey = MuskeyFormatter(
        masks: ['+1 (###) ####-###'],
      );

      final res = muskey.formatEditUpdate(
        const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(
            offset: 0,
          ),
        ),
        const TextEditingValue(
          text: '13123456', // we pasted something
          selection: TextSelection.collapsed(
            offset: 8,
          ),
        ),
      );
      expect(res.text, '+1 (312) 3456');
      expect(muskey.info.isValid, false);
      expect(res.selection.extentOffset, 13);

      final res2 = muskey.formatEditUpdate(
        const TextEditingValue(
          text: '+1 (312) 3456',
          selection: TextSelection.collapsed(
            offset: 13,
          ),
        ),
        const TextEditingValue(
          text: '+1 (312) 34567', // appended to end from keyboard
          selection: TextSelection.collapsed(
            offset: 14,
          ),
        ),
      );
      expect(res2.text, '+1 (312) 3456-7');
      expect(muskey.info.isValid, false);
      expect(res2.selection.extentOffset, 15);

      final res3 = muskey.formatEditUpdate(
        const TextEditingValue(
          text: '+1 (312) 3456-7',
          selection: TextSelection.collapsed(
            offset: 7,
          ),
        ),
        const TextEditingValue(
          text: '+1 (3120) 3456-7', // inserted somewhere in the middle
          selection: TextSelection.collapsed(
            offset: 8,
          ),
        ),
      );
      expect(res3.text, '+1 (312) 0345-67');
      expect(muskey.info.isValid, false);
      expect(res3.selection.extentOffset, 10);

      final res4 = muskey.formatEditUpdate(
        const TextEditingValue(
          text: '+1 (312) 0345-67',
          selection: TextSelection.collapsed(
            offset: 1,
          ),
        ),
        const TextEditingValue(
          text: '+31 (312) 0345-67', // inserted somewhere illegal
          selection: TextSelection.collapsed(
            offset: 2,
          ),
        ),
      );
      expect(res4.text, '+1 (312) 0345-67');
      expect(muskey.info.isValid, false);
      expect(res4.selection.extentOffset, 1);

      final res5 = muskey.formatEditUpdate(
        const TextEditingValue(
          text: '+1 (312) 0345-67',
          selection: TextSelection.collapsed(
            offset: 16,
          ),
        ),
        const TextEditingValue(
          text: '+1 (312) 0345-67999', // inserted with overflow
          selection: TextSelection.collapsed(
            offset: 19,
          ),
        ),
      );
      expect(res5.text, '+1 (312) 0345-67999');
      expect(muskey.info.isValid, true);
      expect(res5.selection.extentOffset, 19);

      final res6 = muskey.formatEditUpdate(
        const TextEditingValue(
          text: '+1 (312) 0345-67999',
          selection: TextSelection.collapsed(
            offset: 19,
          ),
        ),
        const TextEditingValue(
          text: '+1 (312) 0345-679', // exact match
          selection: TextSelection.collapsed(
            offset: 17,
          ),
        ),
      );
      expect(res6.text, '+1 (312) 0345-679');
      expect(muskey.info.isValid, true);
      expect(res6.selection.extentOffset, 17);
    });
  });
}

void customDecoratorChecks() {
  group('Custom Decorator Checks', () {
    test('Decorators override wildcards and solid input units', () {
      const mask = '###123w###123w';
      final muskey = MuskeyFormatter(
        masks: [mask],
        decorators: ['#', '1', '2', '3'],
      );
      final res = muskey.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'ww',
          selection: TextSelection.collapsed(
            offset: 2,
          ),
        ),
      );
      expect(res.text, mask);
      expect(muskey.info.isValid, true);
    });

    test('Usage of regex expressions as decorators', () {
      const mask = '@123@456@789@';
      final muskey = MuskeyFormatter(
        masks: [mask],
        decorators: [RegExp('[0-9]')],
      );
      final res = muskey.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'abcd',
          selection: TextSelection.collapsed(
            offset: 4,
          ),
        ),
      );
      expect(res.text, 'a123b456c789d');
      expect(muskey.info.isValid, true);
    });
  });
}

void customWildcardChecks() {
  group('Custom Wildcards', () {
    test('Custom Wildcards', () {
      const mask = '_###_###_';
      final muskey = MuskeyFormatter(
        masks: [mask],
        wildcards: {
          '_': RegExp('[0-4]'),
          '#': RegExp('[5-9]'),
        },
      );
      final res1 = muskey.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '199929993',
          selection: TextSelection.collapsed(
            offset: 2,
          ),
        ),
      );
      expect(res1.text, '199929993');
      expect(muskey.info.isValid, true);

      final res2 = muskey.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '599929993',
          selection: TextSelection.collapsed(
            offset: 2,
          ),
        ),
      );
      expect(res2.text, '');
    });

    test(
      'A stupid test on just setting a wildcard to accept another char',
      () {
        const mask = '1234';
        final muskey = MuskeyFormatter(
          masks: [mask],
          wildcards: {
            '4': '5',
          },
        );
        final res1 = muskey.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(
            text: '1234',
            selection: TextSelection.collapsed(
              offset: 4,
            ),
          ),
        );
        expect(res1.text, '');
        final res2 = muskey.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(
            text: '1235',
            selection: TextSelection.collapsed(
              offset: 4,
            ),
          ),
        );
        expect(res2.text, '1235');
      },
    );
  });
}

void autocompleteChecks() {
  group('Autocomplete', () {
    test('Autocomplete', () {
      const mask = '+380 (##) ###-##-##';
      final muskey = MuskeyFormatter(
        masks: [mask],
        allowAutofill: true,
      );

      final res = muskey.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '1',
          selection: TextSelection.collapsed(
            offset: 1,
          ),
        ),
      );
      expect(res.text, '+380 (1');
      expect(res.selection.baseOffset, 7);
    });
  });
}
