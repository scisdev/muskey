import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muskey/muskey.dart';

void main() {
  runApp(const MuskeyShowcase());
}

class MuskeyShowcase extends StatelessWidget {
  const MuskeyShowcase({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _c;

  @override
  void initState() {
    _c = TabController(
      length: 4,
      vsync: this,
    )..addListener(() => setState(() {}));

    super.initState();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Muskey showcase'),
        ),
        body: TabBarView(
          controller: _c,
          children: [
            PageOne(controller: _c),
            PageTwo(controller: _c),
            PageThree(controller: _c),
            const PageFour(),
          ],
        ),
        bottomNavigationBar: BotNavBar(_c),
      ),
    );
  }
}

class BotNavBar extends StatelessWidget {
  final TabController _c;
  const BotNavBar(this._c, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                if (_c.index == 0) return;

                _c.animateTo(
                  _c.index - 1,
                  duration: const Duration(milliseconds: 450),
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: Container(
                  key: ValueKey(_c.index == 0),
                  color: _c.index == 0
                      ? Theme.of(context).scaffoldBackgroundColor
                      : Theme.of(context).colorScheme.primary,
                  child: Center(
                    child: Text(
                      'PREVIOUS',
                      style: TextStyle(
                          fontSize: 20,
                          color: _c.index == 0
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(.7)
                              : Theme.of(context).scaffoldBackgroundColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_c.index == 3) return;

                _c.animateTo(
                  _c.index + 1,
                  duration: const Duration(milliseconds: 450),
                );
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: Container(
                  key: ValueKey(_c.index == 3),
                  color: _c.index == 3
                      ? Theme.of(context).scaffoldBackgroundColor
                      : Theme.of(context).colorScheme.primary,
                  child: Center(
                    child: Text(
                      'NEXT',
                      style: TextStyle(
                        fontSize: 20,
                        color: _c.index == 3
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(.7)
                            : Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PageOne extends StatefulWidget {
  final TabController controller;
  const PageOne({Key? key, required this.controller}) : super(key: key);

  @override
  _PageOneState createState() => _PageOneState();
}

class _PageOneState extends State<PageOne> {
  final muskey = MuskeyFormatter(
    masks: ['#### #### #### ####'],
    overflow: OverflowBehavior.forbidden(),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        width: math.min(700, MediaQuery.of(context).size.width),
        height: double.infinity,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Credit Card Number input',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MuskeyFormatter(\n'
                  '    masks: [\'#### #### #### ####\'],\n'
                  '    allowOverflowingInputs: false,\n'
                  ')',
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      inputFormatters: [muskey],
                      onChanged: (_) {
                        setState(() {});
                      },
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Your credit card number',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  ElevatedButton(
                    child: const Text('NEXT'),
                    onPressed: muskey.info.isValid
                        ? () {
                            FocusScope.of(context).unfocus();
                            widget.controller.animateTo(
                              1,
                              duration: const Duration(milliseconds: 450),
                            );
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 45),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'You can easily restrict the first digit to be only 3, 4, 5 or 6, but for this simple example only the basic pattern is sufficient.',
                  textAlign: TextAlign.justify,
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Actual number validation is up to you',
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageTwo extends StatefulWidget {
  final TabController controller;

  const PageTwo({Key? key, required this.controller}) : super(key: key);

  @override
  _PageTwoState createState() => _PageTwoState();
}

class _PageTwoState extends State<PageTwo> {
  final muskey = MuskeyFormatter.countryPhoneMasks(
    allowOverflowingInputs: true,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        width: math.min(700, MediaQuery.of(context).size.width),
        height: double.infinity,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'About 300 world phone masks for login/registration prettiness',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '''
  MuskeyFormatter.countryPhoneMasks(
      allowOverflowingInputs: true,
  );
                  ''',
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      inputFormatters: [muskey],
                      onChanged: (_) {
                        setState(() {});
                      },
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Your phone number',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  ElevatedButton(
                    child: const Text('NEXT'),
                    onPressed: muskey.info.isValid
                        ? () {
                            FocusScope.of(context).unfocus();
                            widget.controller.animateTo(
                              2,
                              duration: const Duration(milliseconds: 450),
                            );
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 45),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'I know that the most common use case for input masks is '
                  'phone number formatting during login/registration. Therefore, '
                  'this lib comes with a built-in list of about 300 phone masks. '
                  'It does a pretty good job of choosing a correct one, and allows for overflow, '
                  'if needed (can be disabled, just pass the parameter to factory constructor)',
                  textAlign: TextAlign.justify,
                ),
              ),
              const SizedBox(height: 45),
              Row(children: [
                Text(
                  'Current clean value is ${muskey.info.clean}, ',
                  textAlign: TextAlign.justify,
                ),
                Text(
                  '${muskey.info.isValid ? '' : 'IN'}VALID',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    color: muskey.info.isValid ? Colors.green : Colors.red,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class PageThree extends StatefulWidget {
  final TabController controller;

  const PageThree({Key? key, required this.controller}) : super(key: key);

  @override
  _PageThreeState createState() => _PageThreeState();
}

class _PageThreeState extends State<PageThree> {
  final muskey = MuskeyFormatter(
    masks: ['#cRaZyDeCoRaToR#iNsIdE#%'],
    decorators: [RegExp('[a-zA-Z]')],
    wildcards: {'#': RegExp('[0-9]'), '%': RegExp('[0|1]')},
    overflow: OverflowBehavior.forbidden(),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        width: math.min(700, MediaQuery.of(context).size.width),
        height: double.infinity,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Easy and powerful customization',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '''
  MuskeyFormatter(
    masks: ['#cRaZyDeCoRaToR#iNsIdE#%'],
    decorators: [RegExp('[a-zA-Z]')],
    wildcards: {'#': RegExp('[0-9]'), '%': RegExp('[0|1]')},
    overflow: OverflowBehavior.forbidden(),
  );
                  ''',
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      inputFormatters: [muskey],
                      onChanged: (_) {
                        setState(() {});
                      },
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Customization!',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                  ElevatedButton(
                    child: const Text('NEXT'),
                    onPressed: muskey.info.isValid
                        ? () {
                            FocusScope.of(context).unfocus();
                            widget.controller.animateTo(
                              3,
                              duration: const Duration(milliseconds: 450),
                            );
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 45),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'You can define custom decorators and wildcards!',
                  textAlign: TextAlign.justify,
                ),
              ),
              const SizedBox(height: 45),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Current clean value is ${muskey.info.clean}',
                  textAlign: TextAlign.justify,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${muskey.info.isValid ? '' : 'IN'}VALID',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    color: muskey.info.isValid ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageFour extends StatefulWidget {
  const PageFour({Key? key}) : super(key: key);

  @override
  _PageFourState createState() => _PageFourState();
}

class _PageFourState extends State<PageFour> {
  final muskey1 = MuskeyFormatter(
    masks: [
      "+55 (##) ####-####",
      "+55 (##) 9####-####",
    ],
    overflow: OverflowBehavior.forbidden(),
  );

  final muskey2 = MuskeyFormatter(
    masks: [
      "+49 (####) ###-####",
      "+49 (###) ###-####",
      "+49 (###) ##-####",
      "+49 (###) ##-###",
      "+49 (###) ##-##",
      "+49-###-###",
    ],
    overflow: OverflowBehavior.forbidden(),
  );

  final muskey3 = MuskeyFormatter(
    masks: ['+380 (##) ###-##-##'],
    overflow: OverflowBehavior.forbidden(),
    allowAutofill: true,
  );

  final muskey4 = MuskeyFormatter.countryPhoneMasks(
    allowOverflowingInputs: true,
  );
  final c = TextEditingController();

  String clearValue = '';

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        width: math.min(700, MediaQuery.of(context).size.width),
        height: double.infinity,
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (MediaQuery.of(context).size.width > 700)
                Row(children: [
                  Expanded(child: brazil()),
                  const SizedBox(width: 50),
                  Expanded(child: germany()),
                ])
              else
                Column(children: [
                  brazil(),
                  const SizedBox(height: 50),
                  germany(),
                ]),
              const SizedBox(height: 50),
              if (MediaQuery.of(context).size.width > 700)
                Row(children: [
                  Expanded(child: ukraine()),
                  const SizedBox(width: 50),
                  Expanded(child: prettifier()),
                ])
              else
                Column(children: [
                  ukraine(),
                  const SizedBox(height: 50),
                  prettifier(),
                ]),
              const SizedBox(height: 50),
              Builder(builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Give me a like? (:'),
                      ),
                    );
                  },
                  child: const Text('Muskey!'),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget brazil() {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          const Text(
            'Brazil 5th digit',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
          ),
          const Text('+55 (##) ####-####'),
          const Text('+55 (##) 9####-####'),
          const Spacer(),
          TextField(
            inputFormatters: [muskey1],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Brazil phones!',
              hintStyle: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget germany() {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          const Text(
            'German phone numbers',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
          ),
          const Text('+49 (####) ###-####'),
          const Text('+49 (###) ###-####'),
          const Text('+49 (###) ##-####'),
          const Text('+49 (###) ##-###'),
          const Text('+49 (###) ##-##'),
          const Text('+49-###-###'),
          const Spacer(),
          TextField(
            inputFormatters: [muskey2],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Germany multichoice!',
              hintStyle: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget ukraine() {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          const Text(
            'Autocomplete',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
          ),
          const Spacer(),
          const Text('''
  MuskeyFormatter(
    masks: ['+380 (##) ###-##-##'],
    overflow: OverflowBehavior.forbidden(),
    allowAutofill: true,
  )
          '''),
          const Spacer(),
          TextField(
            inputFormatters: [muskey3],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Autocomplete!',
              hintStyle: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget prettifier() {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          const Text(
            'Pretty text',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
          ),
          const Spacer(),
          Text('Clear value: $clearValue'),
          const Spacer(flex: 3),
          Row(
            children: [
              Expanded(
                child: TextField(
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  keyboardType: TextInputType.number,
                  controller: c,
                  decoration: const InputDecoration(
                    hintText: 'Enter clean phone number',
                    hintStyle: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 35),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    clearValue = muskey4.prettyText(c.text);
                  });
                },
                child: const Text('Prettify!'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
