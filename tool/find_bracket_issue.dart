import 'dart:io';

void main() {
  final lines = File('lib/features/scoreboard/presentation/scoreboard_screen.dart')
      .readAsLinesSync();
  final stack = <(String, int, int)>[];
  var inString = false;
  for (var ln = 0; ln < lines.length; ln++) {
    final line = lines[ln];
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      final code = c.codeUnitAt(0);
      // Flag any non-ASCII character (possible invisible/lookalike chars)
      if (code > 127) {
        stdout.writeln('NON-ASCII line ${ln + 1} col ${i + 1}: U+${code.toRadixString(16)} ($c)');
      }
      if (inString) {
        if (c == r'\') continue;
        if (c == "'") inString = false;
        continue;
      }
      if (c == "'") {
        inString = true;
      } else if (c == '/' && i + 1 < line.length && line[i + 1] == '/') {
        break;
      } else if (c == '(' || c == '[' || c == '{') {
        stack.add((c, ln + 1, i + 1));
      } else if (c == ')' || c == ']' || c == '}') {
        if (stack.isEmpty) {
          stdout.writeln('EXTRA closer ${c} line ${ln + 1} col ${i + 1}');
        } else {
          final o = stack.removeLast();
          const openers = '([{';
          const closers = ')]}';
          if (openers.indexOf(o.$1) != closers.indexOf(c)) {
            stdout.writeln(
                'MISMATCH line ${ln + 1}: $c closes ${o.$1} from line ${o.$2}');
          }
        }
      }
    }
  }
  for (final o in stack) {
    stdout.writeln('UNCLOSED ${o.$1} from line ${o.$2} col ${o.$3}');
  }
}
