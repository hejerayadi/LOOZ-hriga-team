// LIVE check: are all the SQL files of supabase/ in the REAL database?
// For each file, it looks for things that file creates (a table, a column,
// a function) or removes. Read only, with the app's key: nothing is changed.
//
// Run it from mobile_app/ (needs internet and the .env file):
//   flutter test test_live/database_check_test.dart --dart-define-from-file=.env
//
// A failed line names the file to run in Supabase > SQL Editor. Run the
// files in the order of this list.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/core/supabase_config.dart';

late SupabaseClient client;

/// Codes of PostgREST / Postgres for "this does not exist".
const _missingTable = {'PGRST205', '42P01'};
const _missingColumn = {'42703'};
const _missingFunction = {'PGRST202', '42883'};

Future<bool> _exists(
  Future<Object?> Function() query,
  Set<String> missing,
) async {
  try {
    await query();
    return true;
  } on PostgrestException catch (error) {
    // Any other error (e.g. "permission denied") means it exists.
    return !missing.contains(error.code);
  }
}

Future<bool> hasTable(String table) =>
    _exists(() => client.from(table).select().limit(0), _missingTable);

Future<bool> hasColumn(String table, String column) =>
    _exists(() => client.from(table).select(column).limit(0), _missingColumn);

Future<bool> hasFunction(String name, [Map<String, Object?>? params]) =>
    _exists(() => client.rpc(name, params: params), _missingFunction);

const _noId = '00000000-0000-0000-0000-000000000000';

/// Each SQL file, in the order to run them, and what it leaves in the
/// database ("true" = the file was run).
final sqlFiles = <String, Map<String, Future<bool> Function()>>{
  'looz_schema.sql': {
    for (final table in [
      'profiles',
      'posts',
      'answers',
      'subscriptions',
      'orchard_plans',
      'orchards',
      'trees',
      'sensors',
      'advice',
      'field_actions',
      'alerts',
      'alert_confirmations',
    ])
      'table $table': () => hasTable(table),
  },
  'looz_policies.sql': {
    'column trees.pos_x': () => hasColumn('trees', 'pos_x'),
    'column trees.pos_z': () => hasColumn('trees', 'pos_z'),
    'function my_role()': () => hasFunction('my_role'),
    'function is_admin()': () => hasFunction('is_admin'),
    'function owns_orchard()': () =>
        hasFunction('owns_orchard', {'o_id': _noId}),
    'function owns_tree()': () => hasFunction('owns_tree', {'t_id': _noId}),
  },
  'migrations/002_zones_and_nodes.sql': {
    'table zones': () => hasTable('zones'),
    'table nodes': () => hasTable('nodes'),
    'column trees.zone_id': () => hasColumn('trees', 'zone_id'),
    'column sensors.node_id': () => hasColumn('sensors', 'node_id'),
    'column alerts.zone_id': () => hasColumn('alerts', 'zone_id'),
    'column advice.zone_id': () => hasColumn('advice', 'zone_id'),
    'function owns_zone()': () => hasFunction('owns_zone', {'z_id': _noId}),
    'function zone_in_orchard()': () =>
        hasFunction('zone_in_orchard', {'z_id': _noId, 'o_id': _noId}),
  },
  'migrations/003_node_sensors_and_tree_photos.sql': {
    'table tree_photos': () => hasTable('tree_photos'),
    'view tree_latest_photos': () => hasTable('tree_latest_photos'),
    'column sensors.tree_id removed': () async =>
        !await hasColumn('sensors', 'tree_id'),
    'column trees.health removed': () async =>
        !await hasColumn('trees', 'health'),
  },
  'migrations/004_subscription_plans.sql': {
    'column alerts.tree_id': () => hasColumn('alerts', 'tree_id'),
    'column subscriptions.user_id': () => hasColumn('subscriptions', 'user_id'),
    'column subscriptions.plan': () => hasColumn('subscriptions', 'plan'),
    'column subscriptions.started_at': () =>
        hasColumn('subscriptions', 'started_at'),
    'column subscriptions.ends_at': () => hasColumn('subscriptions', 'ends_at'),
    'column subscriptions.farmer_id removed': () async =>
        !await hasColumn('subscriptions', 'farmer_id'),
    'function user_plan()': () => hasFunction('user_plan'),
    'function has_plan()': () => hasFunction('has_plan', {'min_plan': 'free'}),
    'function plan_rank()': () => hasFunction('plan_rank', {'p': 'free'}),
  },
  'migrations/005_phone_auth_profiles.sql': {
    for (final column in [
      'first_name',
      'last_name',
      'chosen_plan',
      'payment_status',
      'plan_chosen_at',
      'updated_at',
    ])
      'column profiles.$column': () => hasColumn('profiles', column),
    'function choose_plan()': () =>
        hasFunction('choose_plan', {'p_plan': 'free'}),
    'function normalize_phone()': () =>
        hasFunction('normalize_phone', {'p': '216'}),
  },
  'migrations/006_community.sql': {
    'column profiles.is_demo': () => hasColumn('profiles', 'is_demo'),
    'column posts.updated_at': () => hasColumn('posts', 'updated_at'),
    'table comments': () => hasTable('comments'),
    for (final column in ['post_id', 'author_id', 'hidden', 'created_at'])
      'column comments.$column': () => hasColumn('comments', column),
    'view community_posts': () =>
        hasColumn('community_posts', 'comment_count, has_expert_answer'),
    'view community_comments': () =>
        hasColumn('community_comments', 'author_first_name'),
    'function public_profile()': () =>
        hasFunction('public_profile', {'p_user': _noId}),
    'function community_text_ok()': () =>
        hasFunction('community_text_ok', {'t': 'x', 'max_length': 10}),
  },
  // (The private bucket "community" itself can't be seen without logging
  // in: test_live/community_photo_live_test.dart uploads into it.)
  'migrations/007_community_photos.sql': {
    'function community_photo_name_ok()': () =>
        hasFunction('community_photo_name_ok', {'p_name': 'x'}),
    'function community_photo_uploads_ok()': () =>
        hasFunction('community_photo_uploads_ok'),
  },
};

void main() {
  setUpAll(() {
    // Real internet (Flutter tests block it by default).
    HttpOverrides.global = null;
    expect(
      SupabaseConfig.hasKeys,
      isTrue,
      reason: 'Run with --dart-define-from-file=.env',
    );
    client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );
  });
  tearDownAll(() => client.dispose());

  var number = 0;
  sqlFiles.forEach((file, checks) {
    number++;
    test('$number. supabase/$file is in the database', () async {
      final missing = <String>[];
      for (final check in checks.entries) {
        if (!await check.value()) missing.add(check.key);
      }
      expect(
        missing,
        isEmpty,
        reason:
            'Not found: ${missing.join(', ')}.\n'
            'Run supabase/$file in Supabase > SQL Editor (and the files '
            'after it, in order).',
      );
    });
  });
}
