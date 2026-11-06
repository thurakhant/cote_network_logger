import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../core/config.dart';
import '../core/models.dart';
import 'assets.dart';
import 'server_contract.dart';

SessionServer createServer() => IoSessionServer();

/// Internal IO implementation. The timing observer measures conversion AND encoding.
class IoSessionServer implements SessionServer {
  IoSessionServer({
    this.onRecordEncoded,
    this.authTimeout = const Duration(seconds: 5),
    this.ackTimeout = const Duration(seconds: 5),
    this.snapshotTimeout = const Duration(seconds: 30),
    this.streamLifetime = const Duration(seconds: 30),
  });
  final void Function(int micros)? onRecordEncoded;
  final Duration authTimeout, ackTimeout, snapshotTimeout, streamLifetime;
  HttpServer? _server;
  _Admission? _admission;
  int get activeConnections => _admission?.count ?? 0;
  int get activeStreams => _peers.length;
  ServerStart? _started;
  String? _token;
  late LoggerConfig _config;
  late LoggerSnapshot Function() _snapshot;
  late void Function() _clear;
  StreamSubscription<LoggerChange>? _changes;
  final _authorities = <String>{};
  final _failures = <DateTime>[];
  final _peers = <_Peer>{};
  HttpResponse? _activeSnapshot;
  int _epoch = 0;
  @override
  LoggerPlatformSupport get platformSupport => LoggerPlatformSupport.supported;
  @override
  Future<ServerStart> start(
    LoggerConfig config, {
    required LoggerSnapshot Function() snapshot,
    required void Function() clear,
    required Stream<LoggerChange> changes,
  }) async {
    if (_started != null) return _started!;
    if (!config.enabled) return ServerStart(status: LoggerStartStatus.disabled);
    _config = config;
    _snapshot = snapshot;
    _clear = clear;
    String identity;
    try {
      final random = Random.secure();
      String secret(int bytes) => base64Url
          .encode(List.generate(bytes, (_) => random.nextInt(256)))
          .replaceAll('=', '');
      _token = secret(32);
      identity = secret(18);
    } catch (_) {
      return ServerStart(status: LoggerStartStatus.authInitializationFailed);
    }
    try {
      final candidates = <String>{};
      if (config.access == DashboardAccess.lan) {
        for (final interface
            in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
          for (final address in interface.addresses) {
            if (!address.isLoopback) candidates.add(address.address);
          }
        }
      }
      if (config.advertisedAddress != null &&
          !candidates.contains(config.advertisedAddress)) {
        _token = null;
        return ServerStart(status: LoggerStartStatus.bindFailed);
      }
      final listener = await ServerSocket.bind(
        config.access == DashboardAccess.lan
            ? InternetAddress.anyIPv4
            : InternetAddress.loopbackIPv4,
        config.port,
      );
      final admission = _Admission(listener, authTimeout);
      _admission = admission;
      final server = HttpServer.listenOn(admission);
      _server = server;
      _epoch++;
      final port = server.port;
      _authorities.addAll({
        'localhost:$port',
        '127.0.0.1:$port',
        for (final c in candidates) '$c:$port',
      });
      final urls = candidates
          .map((c) => Uri(scheme: 'http', host: c, port: port, path: '/'))
          .toList();
      final dashboard = Uri(
        scheme: 'http',
        host: config.advertisedAddress ?? '127.0.0.1',
        port: port,
        path: '/',
      );
      _started = ServerStart(
        status: LoggerStartStatus.running,
        sessionId: identity,
        dashboardUri: dashboard,
        lanCandidates: urls,
        warningCodes: config.access == DashboardAccess.lan && candidates.isEmpty
            ? ['noLanCandidate']
            : [],
      );
      _changes = changes.listen((change) {
        for (final peer in _peers.toList()) {
          peer.changed(change);
        }
      });
      server.listen(
        (request) {
          unawaited(_handle(request));
        },
        onError: (Object _) {},
      );
      return _started!;
    } on SocketException catch (e) {
      _token = null;
      return ServerStart(
        status: ([48, 98, 10048].contains(e.osError?.errorCode) ||
                (e.osError?.errorCode == -1 &&
                    (e.osError?.message.contains('shared flag') ?? false)))
            ? LoggerStartStatus.addressInUse
            : LoggerStartStatus.bindFailed,
      );
    } catch (_) {
      _token = null;
      return ServerStart(status: LoggerStartStatus.bindFailed);
    }
  }

  @override
  Uri? pairingUri({Uri? dashboardUri}) {
    if (_started == null || _token == null) return null;
    final uri = dashboardUri ?? _started!.dashboardUri!;
    if (uri.scheme != 'http' ||
        uri.userInfo.isNotEmpty ||
        !_authorities.contains(uri.authority.toLowerCase()) ||
        uri.query.isNotEmpty ||
        (uri.path != '/' && uri.path.isNotEmpty)) {
      return null;
    }
    return uri.replace(fragment: 'token=$_token');
  }

  @override
  Future<void> stop() async {
    _epoch++;
    _token = null;
    _started = null;
    _authorities.clear();
    _failures.clear();
    await _changes?.cancel();
    _changes = null;
    for (final peer in _peers.toList()) {
      peer.close();
    }
    _activeSnapshot?.deadline = Duration.zero;
    _activeSnapshot = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
    await _admission?.close();
    _admission = null;
  }

  bool get _limited {
    final oldest = DateTime.now().subtract(const Duration(minutes: 1));
    _failures.removeWhere((time) => time.isBefore(oldest));
    return _failures.length >= 10;
  }

  bool _authenticate(String value) {
    final expected = _token ?? '';
    var difference = value.length ^ expected.length;
    for (var i = 0; i < expected.length; i++) {
      difference |=
          expected.codeUnitAt(i) ^ (i < value.length ? value.codeUnitAt(i) : 0);
    }
    if (difference == 0 && _token != null) return true;
    if (!_limited) _failures.add(DateTime.now());
    return false;
  }

  void _headers(HttpResponse response) {
    response.headers.set('cache-control', 'no-store');
    response.headers.set('referrer-policy', 'no-referrer');
    response.headers.set('x-content-type-options', 'nosniff');
    response.headers.set(
      'content-security-policy',
      "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'",
    );
  }

  Future<void> _error(HttpResponse response, int status, String code) async {
    response.statusCode = status;
    if (status == 401) response.headers.set('www-authenticate', 'Bearer');
    if (status == 429) response.headers.set('retry-after', '60');
    response.headers.contentType = ContentType.json;
    response.write(
      jsonEncode({
        'schemaVersion': 2,
        'error': {'code': code},
      }),
    );
    await response.close();
  }

  Map<String, Object?> _identity(LoggerSnapshot snapshot) => {
        'schemaVersion': 2,
        'sessionId': snapshot.sessionId,
        'version': snapshot.version,
        'clearGeneration': snapshot.clearGeneration,
      };
  Future<void> _json(HttpResponse response, Object value) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(value));
    await response.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    // Subscribe paused before writing any response: otherwise dart:io silently
    // drains an untrusted request body before it sends error headers.
    final body = StreamController<List<int>>(sync: true);
    final input = request.listen(
      body.add,
      onError: body.addError,
      onDone: body.close,
    )..pause();
    body.onListen = input.resume;
    body.onPause = input.pause;
    body.onResume = input.resume;
    body.onCancel = input.cancel;
    if (!request.headers.chunkedTransferEncoding &&
        request.contentLength <= 0) {
      input.resume();
    }
    unawaited(
      response.done
          .then((_) => input.cancel(), onError: (Object _) => input.cancel()),
    );
    _headers(response);
    // One HTTP request per admitted connection. This prevents a pipeline queue.
    response.persistentConnection = false;
    response.deadline = snapshotTimeout;
    final info = request.connectionInfo;
    final admission = _admission;
    final connection = admission
        ?.handled('${info?.remoteAddress.address}:${info?.remotePort}');
    unawaited(
      response.done.then(
        (_) => admission?.completed(connection),
        onError: (Object _) => admission?.completed(connection),
      ),
    );

    try {
      var headerBytes = 0;
      request.headers.forEach((key, values) {
        headerBytes += utf8.encode(key).length +
            values.fold<int>(0, (n, v) => n + utf8.encode(v).length + 4);
      });
      if (headerBytes > 16384) {
        return await _error(response, 413, 'requestTooLarge');
      }
      final host = request.headers.value('host')?.toLowerCase();
      if (!_authorities.contains(host)) {
        return await _error(response, 403, 'forbiddenHost');
      }
      final origin = request.headers.value('origin');
      if (origin != null &&
          !_authorities.any((authority) => origin == 'http://$authority')) {
        return await _error(response, 403, 'forbiddenOrigin');
      }
      if (request.headers.value('upgrade') != null) {
        return await _error(response, 400, 'invalidUpgrade');
      }
      final path = request.uri.path;
      if (['/logs', '/logs/clear', '/ws'].contains(path)) {
        return await _error(response, 410, 'unsupportedVersion');
      }
      final public = ['/', '/dashboard.js', '/dashboard.css'].contains(path);
      final known = public ||
          [
            '/api/v2/session',
            '/api/v2/calls',
            '/api/v2/events',
            '/api/v2/events/ack',
          ].contains(path);
      if (!known) return await _error(response, 404, 'notFound');
      final allowed = path == '/api/v2/events/ack'
          ? ['POST']
          : path == '/api/v2/calls'
              ? ['GET', 'DELETE']
              : ['GET'];
      if (!allowed.contains(request.method)) {
        response.headers.set('allow', allowed.join(', '));
        return await _error(response, 405, 'methodNotAllowed');
      }
      if (path != '/api/v2/events/ack' &&
          request.contentLength != 0 &&
          (request.contentLength > 0 ||
              request.headers.chunkedTransferEncoding)) {
        return await _error(response, 413, 'requestTooLarge');
      }
      if (public) {
        response.headers.contentType = ContentType(
          'text',
          path == '/'
              ? 'html'
              : path.endsWith('.js')
                  ? 'javascript'
                  : 'css',
          charset: 'utf-8',
        );
        response.write(
          path == '/'
              ? dashboardHtml
              : path.endsWith('.js')
                  ? dashboardJs
                  : dashboardCss,
        );
        await response.close();
        return;
      }
      if (_limited) return await _error(response, 429, 'rateLimited');
      final auth = request.headers.value('authorization') ?? '';
      if (!auth.startsWith('Bearer ') || !_authenticate(auth.substring(7))) {
        if (!auth.startsWith('Bearer ') && !_limited) {
          _failures.add(DateTime.now());
        }
        return await _error(response, 401, 'unauthorized');
      }
      if (path == '/api/v2/events') {
        if (_peers.length >= 4) {
          return await _error(response, 429, 'rateLimited');
        }
        response.headers.contentType = ContentType('application', 'x-ndjson');
        response.bufferOutput = false;
        response.deadline = streamLifetime + authTimeout;
        final peer = _Peer(this, response);
        _peers.add(peer);
        peer.attach();
        return;
      }
      if (path == '/api/v2/events/ack') return await _ack(request, body.stream);
      if (request.method == 'DELETE') {
        _clear();
        return await _json(response, _identity(_snapshot()));
      }
      if (path == '/api/v2/session') {
        return await _json(response, {
          ..._identity(_snapshot()),
          'limits': _config.limits.toJson(),
          'capabilities': {
            'capturePoint': 'dio',
            'harExport': true,
            'jsonExport': true,
            'replay': false,
          },
        });
      }
      if (_activeSnapshot != null) {
        return await _error(response, 429, 'rateLimited');
      }
      final snapshot = _snapshot();
      final etag = '"${snapshot.sessionId}:${snapshot.version}"';
      response.headers.set('etag', etag);
      if (request.headers.value('if-none-match') == etag) {
        response.statusCode = 304;
        await response.close();
        return;
      }
      await _stream(response, snapshot);
    } catch (_) {
      try {
        await _error(response, 500, 'internalError');
      } catch (_) {}
    }
  }

  Future<void> _ack(HttpRequest request, Stream<List<int>> body) async {
    final response = request.response;
    if (request.headers.chunkedTransferEncoding ||
        request.contentLength < 0 ||
        request.contentLength > 512) {
      return await _error(response, 413, 'requestTooLarge');
    }
    final type = request.headers.contentType;
    if (type?.mimeType != 'application/json' ||
        (type?.charset != null && type!.charset!.toLowerCase() != 'utf-8')) {
      return await _error(response, 415, 'unsupportedMediaType');
    }
    response.deadline = authTimeout;
    final bytes = <int>[];
    try {
      await for (final chunk in body.timeout(authTimeout)) {
        if (bytes.length + chunk.length > 512) {
          return await _error(response, 413, 'requestTooLarge');
        }
        bytes.addAll(chunk);
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map ||
          value.length != 3 ||
          value['sessionId'] is! String ||
          value['clientId'] is! String ||
          value['version'] is! int) {
        return await _error(response, 400, 'invalidAcknowledgement');
      }
      _Peer? peer;
      for (final candidate in _peers) {
        if (candidate.id == value['clientId']) {
          peer = candidate;
          break;
        }
      }
      if (peer == null ||
          !peer.ack(value['sessionId'] as String, value['version'] as int)) {
        return await _error(response, 400, 'invalidAcknowledgement');
      }
      response.statusCode = 204;
      await response.close();
    } on TimeoutException {
      await _error(response, 408, 'requestTimeout');
    } on FormatException {
      await _error(response, 400, 'invalidAcknowledgement');
    }
  }

  Future<void> _stream(HttpResponse response, LoggerSnapshot snapshot) async {
    _activeSnapshot = response;
    final epoch = _epoch;
    var cancelled = false;
    response.deadline = snapshotTimeout;
    final timer = Timer(snapshotTimeout, () {
      cancelled = true;
    });
    unawaited(
      response.done.then(
        (_) {
          cancelled = true;
        },
        onError: (Object _) {
          cancelled = true;
        },
      ),
    );
    try {
      response.headers.contentType = ContentType.json;
      final header = jsonEncode(_identity(snapshot));
      response.write('${header.substring(0, header.length - 1)},"calls":[');
      for (var i = 0; i < snapshot.calls.length; i++) {
        if (cancelled || epoch != _epoch) return;
        final watch = Stopwatch()..start();
        final bytes = utf8.encode(
          jsonEncode(CoreRecords.callEncodingView(snapshot.calls[i])),
        );
        watch.stop();
        onRecordEncoded?.call(watch.elapsedMicroseconds);
        if (i > 0) response.write(',');
        response.add(bytes);
        await response.flush().timeout(snapshotTimeout);
        await Future<void>.delayed(Duration.zero);
      }
      if (!cancelled && epoch == _epoch) {
        response.write(']}');
        await response.close().timeout(snapshotTimeout);
        response.deadline = null;
      }
    } catch (_) {
      response.deadline = Duration.zero;
    } finally {
      timer.cancel();
      if (identical(_activeSnapshot, response)) _activeSnapshot = null;
    }
  }
}

class _Peer {
  _Peer(this.server, this.response)
      : id = base64Url
            .encode(List.generate(18, (_) => Random.secure().nextInt(256)));
  final IoSessionServer server;
  final HttpResponse response;
  final String id;
  Timer? deadline, throttle, lifetime;
  bool closed = false;
  int? unacked, lastAck, pending;
  String session = '';
  DateTime lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  void attach() {
    final snapshot = server._snapshot();
    session = snapshot.sessionId;
    unawaited(
      response.done.then((_) => close(), onError: (Object _) => close()),
    );
    lifetime = Timer(server.streamLifetime, () => close(graceful: true));
    _send(snapshot.version, initial: true);
  }

  void close({bool graceful = false}) {
    if (closed) return;
    closed = true;
    deadline?.cancel();
    throttle?.cancel();
    lifetime?.cancel();
    server._peers.remove(this);
    if (graceful) {
      unawaited(
        response.close().timeout(server.authTimeout).then(
          (_) {
            response.deadline = null;
          },
          onError: (Object _) {
            response.deadline = Duration.zero;
          },
        ),
      );
    } else {
      response.deadline = Duration.zero;
    }
  }

  bool ack(String identity, int version) {
    if (closed || identity != session) {
      close();
      return false;
    }
    if (version == lastAck) return true;
    if (version != unacked) {
      close();
      return false;
    }
    lastAck = version;
    unacked = null;
    deadline?.cancel();
    _schedule();
    return true;
  }

  void changed(LoggerChange change) {
    if (closed || change.sessionId != session) return;
    if (change.version <= (pending ?? unacked ?? lastAck ?? -1)) return;
    pending = change.version;
    _schedule();
  }

  void _schedule() {
    if (closed || unacked != null || pending == null || throttle != null) {
      return;
    }
    final remaining =
        const Duration(milliseconds: 250) - DateTime.now().difference(lastSent);
    throttle = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      throttle = null;
      if (closed || unacked != null || pending == null) return;
      final version = pending!;
      pending = null;
      _send(version);
    });
  }

  void _send(int version, {bool initial = false}) {
    deadline?.cancel();
    unacked = version;
    lastSent = DateTime.now();
    response.write('${jsonEncode({
          'type': initial ? 'authenticated' : 'changed',
          if (initial) 'schemaVersion': 2,
          if (initial) 'clientId': id,
          'sessionId': session,
          'version': version,
        })}\n');
    unawaited(
      response.flush().catchError((Object _) {
        close();
      }),
    );
    deadline = Timer(server.ackTimeout, close);
  }
}

/// Admission happens before the SDK HTTP parser sees a socket. The SDK still
/// permits up to 1 MiB of headers per admitted connection; 16 KiB is post-parse.
class _Admission extends Stream<Socket> implements ServerSocket {
  _Admission(this.source, this.handshakeTimeout);
  final ServerSocket source;
  final Duration handshakeTimeout;
  final _sockets = <Socket, Timer>{};
  final _ports = <String, Socket>{};
  int get count => _sockets.length;
  @override
  InternetAddress get address => source.address;
  @override
  int get port => source.port;
  Socket? handled(String key) {
    final socket = _ports[key];
    _sockets[socket]?.cancel();
    return socket;
  }

  void completed(Socket? socket) {
    _ports.removeWhere((_, value) => identical(value, socket));
    _sockets.remove(socket)?.cancel();
  }

  @override
  StreamSubscription<Socket> listen(
    void Function(Socket)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return source.listen(
      (socket) {
        if (_sockets.length >= 12) {
          socket.destroy();
          return;
        }
        final key = '${socket.remoteAddress.address}:${socket.remotePort}';
        _ports[key] = socket;
        void release() {
          completed(socket);
        }

        _sockets[socket] = Timer(handshakeTimeout, () {
          socket.destroy();
          release();
        });
        unawaited(
          socket.done.then((_) => release(), onError: (Object _) => release()),
        );
        onData?.call(socket);
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<ServerSocket> close() async {
    for (final entry in _sockets.entries.toList()) {
      entry.value.cancel();
      entry.key.destroy();
    }
    _sockets.clear();
    _ports.clear();
    return source.close();
  }
}
