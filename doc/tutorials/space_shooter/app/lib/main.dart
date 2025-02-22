import 'dart:html'; // ignore: avoid_web_libraries_in_flutter

import 'package:flutter/widgets.dart';
import 'package:tutorials_space_shooter/step1/main.dart' as step1;
import 'package:tutorials_space_shooter/step2/main.dart' as step2;
import 'package:tutorials_space_shooter/step3/main.dart' as step3;
import 'package:tutorials_space_shooter/step4/main.dart' as step4;

void main() {
  var page = window.location.search ?? '';
  if (page.startsWith('?')) {
    page = page.substring(1);
  }

  switch (page) {
    case 'step1':
      step1.main();
      break;
    case 'step2':
      step2.main();
      break;
    case 'step3':
      step3.main();
      break;
    case 'step4':
      step4.main();
      break;

    default:
      runApp(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Error: unknown page name "$page"'),
        ),
      );
  }
}
