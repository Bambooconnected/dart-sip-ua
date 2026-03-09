import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sip_ua/src/sip_ua_helper.dart';
import '../logger.dart';

typedef OnMessageCallback = void Function(dynamic msg);
typedef OnCloseCallback = void Function(int? code, String? reason);
typedef OnOpenCallback = void Function();

class SIPUAWebSocketImpl {
  SIPUAWebSocketImpl(this._url, this.messageDelay);

  final String _url;
  WebSocket? _socket;
  OnOpenCallback? onOpen;
  OnMessageCallback? onMessage;
  OnCloseCallback? onClose;
  final int messageDelay;

  /// Message queue — replaced on each connect() to avoid the Dart
  /// single-subscription stream re-listen restriction.
  StreamController<dynamic>? _queue;
  StreamSubscription<dynamic>? _queueSubscription;

  void connect(
      {Iterable<String>? protocols,
      required WebSocketSettings webSocketSettings}) async {
    _resetQueue();
    logger.i('connect $_url, ${webSocketSettings.extraHeaders}, $protocols');
    try {
      if (webSocketSettings.allowBadCertificate) {
        /// Allow self-signed certificate, for test only.
        _socket = await _connectForBadCertificate(_url, webSocketSettings);
      } else {
        _socket = await WebSocket.connect(_url,
            protocols: protocols, headers: webSocketSettings.extraHeaders);
      }

      onOpen?.call();
      _socket!.listen((dynamic data) {
        onMessage?.call(data);
      }, onDone: () {
        onClose?.call(_socket!.closeCode, _socket!.closeReason);
      });
    } catch (e) {
      onClose?.call(500, e.toString());
    }
  }

  /// Creates a fresh single-subscription queue with error handling.
  /// Safe to call on every connect() — the old queue/subscription is
  /// cleaned up first.
  void _resetQueue() {
    _queueSubscription?.cancel();
    _queue?.close();
    _queue = StreamController<dynamic>();
    _queueSubscription = _queue!.stream
        .asyncMap((dynamic event) async {
          await Future<void>.delayed(Duration(milliseconds: messageDelay));
          return event;
        })
        .listen(
          (dynamic event) {
            try {
              _socket!.add(event);
              logger.d('send: \n\n$event');
            } catch (e) {
              logger.e('WebSocket send failed: $e');
            }
          },
          onError: (dynamic error) {
            logger.e('WebSocket queue error: $error');
          },
        );
  }

  void send(dynamic data) {
    if (_socket != null && _queue != null && !_queue!.isClosed) {
      _queue!.add(data);
    } else {
      logger.e(
          'WebSocket send dropped: socket=${_socket != null}, queue=${_queue != null}');
    }
  }

  void close() {
    if (_socket != null) _socket!.close();
  }

  bool isConnecting() {
    return _socket != null && _socket!.readyState == WebSocket.connecting;
  }

  /// For test only.
  Future<WebSocket> _connectForBadCertificate(
      String url, WebSocketSettings webSocketSettings) async {
    try {
      Random r = Random();
      String key = base64.encode(List<int>.generate(16, (_) => r.nextInt(255)));
      SecurityContext securityContext = SecurityContext();
      HttpClient client = HttpClient(context: securityContext);

      if (webSocketSettings.userAgent != null) {
        client.userAgent = webSocketSettings.userAgent;
      }

      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        logger.w('Allow self-signed certificate => $host:$port. ');
        return true;
      };

      Uri parsed_uri = Uri.parse(url);
      Uri uri = parsed_uri.replace(
          scheme: parsed_uri.scheme == 'wss' ? 'https' : 'http');

      HttpClientRequest request =
          await client.getUrl(uri); // form the correct url here
      request.headers.add('Connection', 'Upgrade', preserveHeaderCase: true);
      request.headers.add('Upgrade', 'websocket', preserveHeaderCase: true);
      request.headers.add('Sec-WebSocket-Version', '13',
          preserveHeaderCase: true); // insert the correct version here
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase(),
          preserveHeaderCase: true);
      request.headers
          .add('Sec-WebSocket-Protocol', 'sip', preserveHeaderCase: true);

      webSocketSettings.extraHeaders.forEach((String key, dynamic value) {
        request.headers.add(key, value, preserveHeaderCase: true);
      });

      HttpClientResponse response = await request.close();
      Socket socket = await response.detachSocket();
      WebSocket webSocket = WebSocket.fromUpgradedSocket(
        socket,
        protocol: 'sip',
        serverSide: false,
      );

      return webSocket;
    } catch (e) {
      logger.e('error $e');
      rethrow;
    }
  }
}
