import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config.dart';
import '../models/resultado_generacion.dart';

enum WsStatus { idle, connecting, running, done, error }

typedef OnGeneration = void Function(ResultadoGeneracion gen);
typedef OnDone = void Function(ResultadoGeneracion final_);
typedef OnError = void Function(String message);

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  void connect({
    required Map<String, dynamic> params,
    required OnGeneration onGeneration,
    required OnDone onDone,
    required OnError onError,
  }) {
    disconnect();
    final uri = Uri.parse('${AppConfig.wsUrl}/ws/optimizar');
    _channel = WebSocketChannel.connect(uri);
    _channel!.sink.add(jsonEncode(params));

    _sub = _channel!.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        switch (msg['tipo']) {
          case 'generacion':
            onGeneration(ResultadoGeneracion.fromJson(msg['datos']));
          case 'finalizado':
            onDone(ResultadoGeneracion.fromJson(msg['datos']));
          case 'error':
            onError(msg['mensaje']?.toString() ?? 'Error desconocido');
        }
      },
      onError: (e) => onError(e.toString()),
      onDone: () {},
      cancelOnError: false,
    );
  }

  void disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
  }
}
