typedef ParsedTrackUrl = ({
  String host,
  List<String> folders,
  String trackId,
  String raw,
});

typedef ParsedPackUrl = ({
  Uri url,
  String id,
});

sealed class ParsedUrl {}

class ParsedTrack extends ParsedUrl {
  final ParsedTrackUrl data;

  ParsedTrack(this.data);
}

class ParsedPack extends ParsedUrl {
  final ParsedPackUrl data;

  ParsedPack(this.data);
}

ParsedUrl? parseUrl(String raw) {
  try {
    final hasScheme = RegExp(r'^[a-z][a-zA-Z0-9+.-]*://')
        .hasMatch(raw);

    final uri = Uri.parse(
      hasScheme ? raw : 'https://$raw',
    );

    // Pack URL
    if (uri.scheme == 'qrjukebox' && uri.host == 'pack') {
      final packUrlString = uri.queryParameters['url'];
      if (packUrlString == null) return null;

      final packUrl = Uri.parse(packUrlString);

      if (packUrl.scheme != 'https' && packUrl.scheme != 'http') {
        return null;
      }

      if (packUrl.pathSegments.isEmpty) return null;

      final filename = packUrl.pathSegments.last;
      if (!filename.toLowerCase().endsWith('.qrj')) return null;

      final id = filename.substring(0, filename.length - 4);
      if (id.isEmpty) return null;

      return ParsedPack((
        url: packUrl,
        id: id,
      ));
    }

    // Track URL
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final segs = uri.pathSegments
          .where((s) => s.isNotEmpty)
          .toList();

      if (uri.host.isNotEmpty && segs.length >= 2) {
        return ParsedTrack((
          host: uri.host,
          folders: segs.sublist(0, segs.length - 1),
          trackId: segs.last,
          raw: raw,
        ));
      }
    }
  } catch (_) {}

  return null;
}
