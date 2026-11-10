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
  'migrations/008_signup_profile_payment.sql': {
    for (final column in ['almond_trees', 'orchard_area_ha', 'irrigation'])
      'column profiles.$column': () => hasColumn('profiles', column),
    'table plan_prices': () => hasTable('plan_prices'),
    'table payments': () => hasTable('payments'),
    'function confirm_payment()': () =>
        hasFunction('confirm_payment', {'p_ref': 'x', 'p_amount': 1}),
  },
  'migrations/009_demo_payment_kits_roles.sql': {
    'table app_settings': () => hasTable('app_settings'),
    'table kit_requests': () => hasTable('kit_requests'),
    // (011 renames per_sensor / sensors to per_node / nodes, and removes
    // request_kit(): either state means 009 was run.)
    'column plan_prices.per_sensor (per_node after 011)': () async =>
        await hasColumn('plan_prices', 'per_sensor') ||
        await hasColumn('plan_prices', 'per_node'),
    'column payments.sensors (nodes after 011)': () async =>
        await hasColumn('payments', 'sensors') ||
        await hasColumn('payments', 'nodes'),
    'column profiles.organisation': () => hasColumn('profiles', 'organisation'),
    'function demo_payment()': () =>
        hasFunction('demo_payment', {'p_plan': 'paid'}),
    'function request_kit() (removed by 011)': () async =>
        await hasFunction('request_kit') ||
        await hasColumn('kit_requests', 'orchard_id'),
    'function choose_role()': () =>
        hasFunction('choose_role', {'p_role': 'farmer'}),
  },
  // (demo_login_check() can only be called by the Edge Function: "permission
  // denied" here means it is there.)
  'migrations/010_demo_login.sql': {
    'column app_settings.demo_login_enabled': () =>
        hasColumn('app_settings', 'demo_login_enabled'),
    'function demo_login_check()': () =>
        hasFunction('demo_login_check', {'p_phone': '+21600000000'}),
  },
  'migrations/011_two_packs_orchard_designer.sql': {
    'column plan_prices.per_node': () => hasColumn('plan_prices', 'per_node'),
    'column payments.kind': () => hasColumn('payments', 'kind'),
    'column subscriptions.nodes': () => hasColumn('subscriptions', 'nodes'),
    'column kit_requests.orchard_id': () =>
        hasColumn('kit_requests', 'orchard_id'),
    for (final column in ['outline', 'design', 'status', 'confirmed_nodes'])
      'column orchards.$column': () => hasColumn('orchards', column),
    for (final column in ['letter', 'zone_type', 'color', 'archived_at'])
      'column zones.$column': () => hasColumn('zones', column),
    'column nodes.installed_at': () => hasColumn('nodes', 'installed_at'),
    'column trees.archived_at': () => hasColumn('trees', 'archived_at'),
    'function orchard_quote()': () => hasFunction('orchard_quote'),
    'function orchard_save_design()': () =>
        hasFunction('orchard_save_design', {'p_design': <String, Object?>{}}),
    'function orchard_apply_design()': () =>
        hasFunction('orchard_apply_design'),
    'function request_kit() removed': () async =>
        !await hasFunction('request_kit'),
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
