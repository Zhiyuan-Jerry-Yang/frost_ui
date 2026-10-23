/// A deliberately small private grammar. Widgets own focus and callbacks.
enum FrostRichTarget { link, mention, hashtag }

class FrostRichNode {
  const FrostRichNode(this.text, {this.bold = false, this.italic = false, this.code = false, this.target, this.value});
  final String text;
  final bool bold, italic, code;
  final FrostRichTarget? target;
  final String? value;
}

class FrostRichDocument {
  FrostRichDocument(String text) : nodes = List.unmodifiable(_RichParser(text).parse());
  final List<FrostRichNode> nodes;
}

class _RichParser {
  _RichParser(this.source);
  final String source;
  static final _word = RegExp(r'[\p{L}\p{N}_]', unicode: true);
  static final _space = RegExp(r'\s');
  // Unescaped full-width sentence punctuation terminates a URL immediately;
  // it is not merely stripped from the end of an already-consumed token.
  static const _urlSentenceBoundary = '，。！？；：、';
  // Sentence punctuation belongs outside automatically detected URLs.
  static const _punctuation = '.,!?;:，。！？；：、"\'”’」』';
  List<FrostRichNode> parse() => _read(0, null, false, false).nodes;
  ({List<FrostRichNode> nodes, int end, bool closed}) _read(int start, String? stop, bool bold, bool italic) {
    final nodes = <FrostRichNode>[], plain = StringBuffer();
    var index = start;
    void flush() {
      if (plain.isNotEmpty) {
        nodes.add(FrostRichNode(plain.toString(), bold: bold, italic: italic));
        plain.clear();
      }
    }

    while (index < source.length) {
      if (stop != null && source.startsWith(stop, index) && !(stop == '*' && source.startsWith('**', index) && !source.startsWith('***', index))) {
        flush();
        return (nodes: nodes, end: index + stop.length, closed: true);
      }
      if (source[index] == '`') {
        final end = source.indexOf('`', index + 1);
        if (end >= 0) {
          flush();
          nodes.add(FrostRichNode(source.substring(index + 1, end), bold: bold, italic: italic, code: true));
          index = end + 1;
          continue;
        }
      }
      if (source[index] == '*') {
        final marker = source.startsWith('**', index) ? '**' : '*';
        final inner = _read(index + marker.length, marker, bold || marker == '**', italic || marker == '*');
        if (inner.closed) {
          flush();
          nodes.addAll(inner.nodes);
          index = inner.end;
          continue;
        }
        plain.write(marker);
        index += marker.length;
        continue;
      }
      if (source[index] == '[') {
        final labelEnd = source.indexOf('](', index + 1);
        if (labelEnd >= 0) {
          final urlEnd = _closeParen(labelEnd + 1);
          if (urlEnd >= 0) {
            final raw = source.substring(labelEnd + 2, urlEnd), uri = Uri.tryParse(source.substring(labelEnd + 2, urlEnd));
            if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
              flush();
              nodes.add(FrostRichNode(source.substring(index + 1, labelEnd), bold: bold, italic: italic, target: FrostRichTarget.link, value: raw));
              index = urlEnd + 1;
              continue;
            }
            plain.write(source.substring(index, urlEnd + 1));
            index = urlEnd + 1;
            continue;
          }
        }
      }
      if (source.startsWith('http://', index) || source.startsWith('https://', index)) {
        var end = index;
        while (end < source.length && !_space.hasMatch(source[end]) && !'< >`*'.contains(source[end]) && !_urlSentenceBoundary.contains(source[end])) {
          end++;
        }
        var url = source.substring(index, end);
        var trimming = true;
        while (trimming && url.isNotEmpty) {
          trimming = false;
          if (_punctuation.contains(url[url.length - 1])) {
            url = url.substring(0, url.length - 1);
            trimming = true;
            continue;
          }
          for (final pair in const [('(', ')'), ('[', ']'), ('{', '}'), ('（', '）'), ('【', '】')]) {
            if (url.endsWith(pair.$2) && pair.$2.allMatches(url).length > pair.$1.allMatches(url).length) {
              url = url.substring(0, url.length - pair.$2.length);
              trimming = true;
              break;
            }
          }
        }
        final uri = Uri.tryParse(url);
        if (uri != null && uri.host.isNotEmpty && url.isNotEmpty) {
          flush();
          nodes.add(FrostRichNode(url, bold: bold, italic: italic, target: FrostRichTarget.link, value: url));
          index += url.length;
          continue;
        }
      }
      if ((source[index] == '@' || source[index] == '#') && (index == 0 || _space.hasMatch(source[index - 1]))) {
        var end = index + 1;
        while (end < source.length) {
          final unit = source.codeUnitAt(end);
          final length = unit >= 0xd800 && unit <= 0xdbff && end + 1 < source.length ? 2 : 1;
          final char = source.substring(end, end + length);
          if (!_word.hasMatch(char)) break;
          end += length;
        }
        if (end > index + 1) {
          flush();
          nodes.add(
            FrostRichNode(
              source.substring(index, end),
              bold: bold,
              italic: italic,
              target: source[index] == '@' ? FrostRichTarget.mention : FrostRichTarget.hashtag,
              value: source.substring(index + 1, end),
            ),
          );
          index = end;
          continue;
        }
      }
      plain.write(source[index]);
      index++;
    }
    flush();
    return (nodes: nodes, end: index, closed: stop == null);
  }

  int _closeParen(int start) {
    var depth = 0;
    for (var i = start; i < source.length; i++) {
      if (source[i] == '(') depth++;
      if (source[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}
