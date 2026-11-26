import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Modelos ──────────────────────────────────────────────────────────────

double? _d(Object? v) => (v as num?)?.toDouble();

class JoinResult {
  JoinResult(Map<String, dynamic> j)
      : sessionId = j['sessionId'] as int,
        displayName = j['displayName'] as String,
        attemptsLeft = j['attemptsLeft'] as int;
  final int sessionId, attemptsLeft;
  final String displayName;
}

class AttemptResult {
  AttemptResult(Map<String, dynamic> j)
      : score = _d(j['score'])!,
        stars = j['stars'] as int,
        rank = j['rank'] as int,
        bestScore = _d(j['bestScore'])!,
        attemptsLeft = j['attemptsLeft'] as int;
  final double score, bestScore;
  final int stars, rank, attemptsLeft;
}

class BoardEntry {
  BoardEntry(Map<String, dynamic> j)
      : rank = j['rank'] as int,
        displayName = j['displayName'] as String,
        score = _d(j['score'])!,
        stars = j['stars'] as int;
  final int rank, stars;
  final String displayName;
  final double score;
}

class BoardEvent {
  BoardEvent(Map<String, dynamic> j)
      : type = j['type'] as String,
        displayName = j['displayName'] as String,
        rank = j['rank'] as int?,
        createdAt = DateTime.parse(j['createdAt'] as String);
  final String type, displayName;
  final int? rank;
  final DateTime createdAt;

  String get text => type == 'finished' ? '$displayName terminó #$rank' : '$displayName entró';
}

class Me {
  Me(Map<String, dynamic> j)
      : rank = j['rank'] as int?,
        bestScore = _d(j['bestScore']),
        attemptsLeft = j['attemptsLeft'] as int;
  final int? rank;
  final double? bestScore;
  final int attemptsLeft;
}

class Leaderboard {
  Leaderboard(Map<String, dynamic> j)
      : sessionId = j['sessionId'] as int,
        top = [for (final e in j['top'] as List) BoardEntry(e as Map<String, dynamic>)],
        me = j['me'] == null ? null : Me(j['me'] as Map<String, dynamic>),
        recent = [for (final e in j['recent'] as List) BoardEvent(e as Map<String, dynamic>)],
        players = j['players'] as int,
        // Diferencia entre el reloj del server y el local, para el "hace N s".
        clockSkew = j['serverTime'] == null
            ? Duration.zero
            : DateTime.parse(j['serverTime'] as String).difference(DateTime.now());
  final int sessionId, players;
  final List<BoardEntry> top;
  final Me? me;
  final List<BoardEvent> recent;
  final Duration clockSkew;
}

// ── Errores ──────────────────────────────────────────────────────────────

/// No hubo red o el server no respondió.
class OfflineException implements Exception {}

/// El server respondió con error. [code] es el campo `error` del JSON.
class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;
  @override
  String toString() => 'ApiException($status, $code)';
}

// ── Servicio ─────────────────────────────────────────────────────────────

abstract interface class LeaderboardService {
  Future<JoinResult> join(String name);
  Future<AttemptResult> submit(String name, List<List<double?>> rounds);
  Future<Leaderboard> fetch(String? name);

  /// Devuelve el id de la sesión nueva.
  Future<int> reset(String pin);
}

class ApiLeaderboardService implements LeaderboardService {
  ApiLeaderboardService({http.Client? client, String? base})
      : _client = client ?? http.Client(),
        _base = base ?? const String.fromEnvironment('API_BASE', defaultValue: '/api');

  final http.Client _client;
  final String _base;

  Uri _uri(String path, [Map<String, String>? q]) =>
      Uri.base.resolve('$_base$path').replace(queryParameters: q);

  Future<Map<String, dynamic>> _send(Future<http.Response> req) async {
    final http.Response r;
    try {
      r = await req.timeout(const Duration(seconds: 8));
    } on Exception {
      throw OfflineException(); // ClientException, TimeoutException…
    }
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300 && body != null) return body;
    // Un proxy caído (502/503 sin JSON) también es "sin conexión".
    if (body == null) throw OfflineException();
    throw ApiException(r.statusCode, body['error'] as String? ?? 'error');
  }

  Future<Map<String, dynamic>> _post(String path, Object body, [Map<String, String>? headers]) =>
      _send(_client.post(_uri(path),
          headers: {'Content-Type': 'application/json', ...?headers}, body: jsonEncode(body)));

  @override
  Future<JoinResult> join(String name) async => JoinResult(await _post('/join', {'name': name}));

  @override
  Future<AttemptResult> submit(String name, List<List<double?>> rounds) async =>
      AttemptResult(await _post('/attempts', {'name': name, 'rounds': rounds}));

  @override
  Future<Leaderboard> fetch(String? name) async =>
      Leaderboard(await _send(_client.get(_uri('/leaderboard', name == null ? null : {'name': name}))));

  @override
  Future<int> reset(String pin) async =>
      (await _post('/admin/reset', const {}, {'X-Admin-Pin': pin}))['sessionId'] as int;
}

// ── Preferencias: nombre, mejor puntaje propio e intentos pendientes ─────
// Todo en try/catch: si falla el almacenamiento la app sigue igual.

class LocalStore {
  SharedPreferences? _p;

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  T? _get<T>(T? Function(SharedPreferences p) f) {
    try {
      return _p == null ? null : f(_p!);
    } catch (_) {
      return null;
    }
  }

  void _set(Future<bool> Function(SharedPreferences p) f) {
    try {
      if (_p != null) f(_p!).catchError((_) => false);
    } catch (_) {}
  }

  String? get name => _get((p) => p.getString('nombre'));
  set name(String? v) => _set((p) => v == null ? p.remove('nombre') : p.setString('nombre', v));

  double? get best => _get((p) => p.getDouble('mejor'));
  set best(double? v) => _set((p) => v == null ? p.remove('mejor') : p.setDouble('mejor', v));

  /// Intentos sin enviar: [{name, rounds}].
  List<Map<String, dynamic>> get pending =>
      _get((p) => [
            for (final e in jsonDecode(p.getString('pendientes') ?? '[]') as List)
              e as Map<String, dynamic>
          ]) ??
      [];
  set pending(List<Map<String, dynamic>> v) =>
      _set((p) => v.isEmpty ? p.remove('pendientes') : p.setString('pendientes', jsonEncode(v)));
}

/// Envía intentos; si no hay red los guarda y reintenta cada 5 s.
class Outbox {
  Outbox(this._service, this._store, {required this.onResult, required this.onRejected});

  final LeaderboardService _service;
  final LocalStore _store;

  /// Un intento pendiente por fin se guardó.
  final void Function(AttemptResult r) onResult;

  /// El server rechazó un pendiente (p. ej. 409 sin_intentos); se descarta.
  final void Function(ApiException e) onRejected;

  Timer? _timer;
  var _flushing = false;

  int get pendingCount => _store.pending.length;

  /// Envía de inmediato. null = sin red, quedó pendiente.
  /// Lanza [ApiException] si el server lo rechaza.
  Future<AttemptResult?> submit(String name, List<List<double?>> rounds) async {
    if (pendingCount == 0) {
      try {
        return await _service.submit(name, rounds);
      } on OfflineException {
        // cae abajo
      }
    }
    _store.pending = [
      ..._store.pending,
      {'name': name, 'rounds': rounds}
    ];
    _schedule();
    return null;
  }

  /// Reintenta lo que haya quedado de una visita anterior.
  void resume() {
    if (pendingCount > 0) _schedule();
  }

  void _schedule() => _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => flush());

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (true) {
        final queue = _store.pending;
        if (queue.isEmpty) break;
        final a = queue.first;
        try {
          final rounds = [
            for (final r in a['rounds'] as List) [for (final t in r as List) _d(t)]
          ];
          final res = await _service.submit(a['name'] as String, rounds);
          _store.pending = queue.sublist(1);
          onResult(res);
        } on OfflineException {
          return; // sigue el Timer
        } on ApiException catch (e) {
          _store.pending = queue.sublist(1);
          onRejected(e);
        } catch (_) {
          _store.pending = queue.sublist(1); // pendiente corrupto: no reintentar para siempre
        }
      }
      _timer?.cancel();
      _timer = null;
    } finally {
      _flushing = false;
    }
  }

  void dispose() => _timer?.cancel();
}
