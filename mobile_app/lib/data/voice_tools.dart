// The TOOLS of the voice assistant "لوز": when Gemini asks for data, the APP
// runs the tool with the farmer's own login (the rules of the database, RLS,
// apply: he only reads his own orchard) and sends back a short JSON. They
// only READ.
// Milestone 1: get_my_orchard (his zones and the last reading of each
// sensor box, migrations 011 + 012). The names of the tools are the ones
// locked in the token (supabase/functions/voice-token).
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/locale.dart';
import '../core/supabase_config.dart';
import '../core/zone_letters.dart';

/// The tool "my orchard" (its name in the token of "voice-token").
const orchardTool = 'get_my_orchard';

abstract class VoiceTools {
  /// Runs the tool [name]: the JSON answer for Gemini (never throws: a
  /// problem is an "error" code in the answer, "لوز" says it can't see).
  Future<Map<String, Object?>> run(String name, Map<String, Object?> args);
}

VoiceTools? _voiceTools;

/// The tools: Supabase in the app (the tests put fake ones).
VoiceTools get voiceTools => _voiceTools ??= SupabaseVoiceTools(supabase);
set voiceTools(VoiceTools tools) => _voiceTools = tools;

class SupabaseVoiceTools implements VoiceTools {
  SupabaseVoiceTools(this._client);

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 10);

  @override
  Future<Map<String, Object?>> run(
    String name,
    Map<String, Object?> args,
  ) async {
    try {
      return switch (name) {
        orchardTool => await myOrchard().timeout(_timeout),
        _ => {'error': 'unknown_tool'},
      };
    } catch (_) {
      // No internet, session ended...: "لوز" says it can't see the orchard.
      return {'error': 'not_available_now'};
    }
  }

  /// His zones, each with the last reading of its sensor box.
  Future<Map<String, Object?>> myOrchard() async {
    final orchard = await _client
        .from('orchards')
        .select('id, status')
        .maybeSingle();
    if (orchard == null || orchard['status'] != 'complete') {
      return {'zones': <Object?>[], 'note': 'orchard_not_drawn_yet'};
    }
    final id = orchard['id'] as String;
    final zones = await _client
        .from('zones')
        .select('id, letter, name, zone_type, tree_count, cultivar')
        .eq('orchard_id', id)
        .isFilter('archived_at', null)
        .order('letter', ascending: true);
    final boxes = await _client
        .from('iot_node_status')
        .select(
          'zone_id, status, measured_at, soil_moisture_pct, soil_temp_c, '
          'air_temp_c, humidity_pct, battery_pct, level, reasons, cause',
        )
        .eq('orchard_id', id);
    return orchardAnswer(zones, boxes, DateTime.now());
  }
}

/// The answer of get_my_orchard (separate, to test it without Supabase).
Map<String, Object?> orchardAnswer(
  List<Map<String, dynamic>> zones,
  List<Map<String, dynamic>> boxes,
  DateTime now,
) {
  final ar = lookupAppLocalizations(const Locale('ar'));
  final fr = lookupAppLocalizations(const Locale('fr'));
  final byZone = {for (final b in boxes) b['zone_id']: b};
  num? round1(Object? v) => v is num ? (v * 10).round() / 10 : null;
  return {
    'now': now.toIso8601String(),
    'zones': [
      for (final z in zones)
        () {
          final letter = '${z['letter'] ?? ''}';
          final box = byZone[z['id']];
          final measured = DateTime.tryParse('${box?['measured_at'] ?? ''}');
          return <String, Object?>{
            'zone_ar': ar.zoneName(zoneLetterIn(letter, 'ar')),
            'zone_fr': fr.zoneName(zoneLetterIn(letter, 'fr')),
            if (z['name'] != null) 'name': z['name'],
            if (z['zone_type'] != null) 'type': z['zone_type'],
            if (z['tree_count'] != null) 'trees': z['tree_count'],
            if (z['cultivar'] != null) 'cultivar': z['cultivar'],
            // none = no sensor box in this zone.
            'box': box?['status'] ?? 'none',
            if (measured != null)
              'minutes_since_reading': now.difference(measured).inMinutes,
            if (box != null) ...{
              for (final key in const [
                'soil_moisture_pct',
                'soil_temp_c',
                'air_temp_c',
                'humidity_pct',
                'battery_pct',
              ])
                if (box[key] != null) key: round1(box[key]),
              if (box['level'] != null) 'level': box['level'],
              if ((box['reasons'] as List?)?.isNotEmpty ?? false)
                'reasons': box['reasons'],
              if (box['cause'] != null) 'cause': box['cause'],
            },
          };
        }(),
    ],
  };
}
