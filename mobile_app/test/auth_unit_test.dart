// The checks of the phone number and the names, the error messages, and
// how a row of the "profiles" table is read.
// Run it with: flutter test
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/validators.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/user_profile.dart';
import 'package:looz_mobile/features/onboarding/auth_messages.dart';

void main() {
  group('phone number', () {
    test('+216 and 8 digits', () {
      expect(isValidPhone('+21698123456'), isTrue);
      expect(isValidPhone(phoneFromDigits('50000001')), isTrue);
      for (final wrong in [
        '21698123456', // no +
        '+2169812345', // 7 digits
        '+216981234567', // 9 digits
        '+33612345678', // not Tunisia
        '+216 98 123 456', // spaces
        '+2169812345a',
        '',
      ]) {
        expect(isValidPhone(wrong), isFalse, reason: wrong);
      }
    });

    test('shown as +216 98 123 456', () {
      expect(formatPhone('+21698123456'), '+216 98 123 456');
      expect(formatPhone(''), '');
    });

    test('the code has 6 digits', () {
      expect(isValidCode('123456'), isTrue);
      expect(isValidCode('12345'), isFalse);
      expect(isValidCode('12345a'), isFalse);
    });
  });

  group('names', () {
    test('letters of any language, spaces, - and \' are fine', () {
      for (final name in [
        'Mohamed',
        'محمد',
        'بن سالم',
        'Ben-Ali',
        "M'barek",
        'Hélène',
        'عبد الرَّحمن', // Arabic marks
      ]) {
        expect(checkName(name), isNull, reason: name);
      }
    });

    test('empty, too long or strange characters are refused', () {
      expect(checkName(''), NameProblem.empty);
      expect(checkName('   '), NameProblem.empty);
      expect(checkName('a' * 51), NameProblem.tooLong);
      expect(checkName('a' * 50), isNull);
      for (final name in [
        'Mohamed2',
        'محمد٣', // Arabic digit
        'Ali!',
        '<script>',
        'a@b',
        'Sami 😀',
        'Ali\u0000', // control character
        'x;drop',
      ]) {
        expect(checkName(name), NameProblem.badCharacters, reason: name);
      }
    });

    test('spaces are cleaned before saving', () {
      expect(cleanName('  Ben   Salem '), 'Ben Salem');
      // A line break (pasted text) becomes a space.
      expect(cleanName('Ali\nBen'), 'Ali Ben');
      expect(checkName('Ali\nBen'), isNull);
    });
  });

  group('errors of Supabase', () {
    test('each error becomes the right message', () {
      final cases = <Object, AuthFailure>{
        const AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ): AuthFailure.wrongCode,
        // Sign in with a number that has no account (checked on the real
        // Supabase: 422, "Signups not allowed for otp").
        const AuthApiException(
          'Signups not allowed for otp',
          statusCode: '422',
          code: 'otp_disabled',
        ): AuthFailure.noAccount,
        const AuthApiException(
          'Unsupported phone provider',
          statusCode: '400',
          code: 'phone_provider_disabled',
        ): AuthFailure.cannotReceiveCode,
        AuthRetryableFetchException(
          message: '{"code":500,"error_code":"sms_send_failed"}',
          statusCode: '500',
        ): AuthFailure.cannotReceiveCode,
        const AuthApiException(
          'wait',
          statusCode: '429',
          code: 'over_sms_send_rate_limit',
        ): AuthFailure.tooManyTries,
        const AuthApiException(
          'Phone already registered',
          statusCode: '422',
          code: 'phone_exists',
        ): AuthFailure.phoneTaken,
        const AuthApiException(
          'Invalid phone',
          statusCode: '400',
          code: 'validation_failed',
        ): AuthFailure.invalidPhone,
        const AuthApiException(
          'Session not found',
          statusCode: '403',
          code: 'session_not_found',
        ): AuthFailure.sessionExpired,
        AuthRetryableFetchException(
          message: 'ClientException: Failed host lookup',
        ): AuthFailure.noInternet,
        TimeoutException('slow'): AuthFailure.noInternet,
        const PostgrestException(message: 'duplicate', code: '23505'):
            AuthFailure.phoneTaken,
        const PostgrestException(message: 'check', code: '23514'):
            AuthFailure.invalidName,
        const PostgrestException(message: 'JWT expired', code: 'PGRST303'):
            AuthFailure.sessionExpired,
        StateError('?'): AuthFailure.unknown,
      };
      cases.forEach((error, failure) {
        expect(failureOf(error), failure, reason: '$error');
      });
    });

    test('every message is 100% Arabic or 100% French', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      final fr = lookupAppLocalizations(const Locale('fr'));
      final latin = RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]');
      final arabic = RegExp('[؀-ۿ]');
      final arTexts = [
        for (final f in AuthFailure.values) failureMessage(ar, f),
        for (final p in NameProblem.values) nameProblemMessage(ar, p),
      ];
      final frTexts = [
        for (final f in AuthFailure.values) failureMessage(fr, f),
        for (final p in NameProblem.values) nameProblemMessage(fr, p),
      ];
      for (final text in arTexts) {
        expect(text, isNot(matches(latin)), reason: text);
        expect(text, matches(arabic), reason: text);
      }
      for (final text in frTexts) {
        expect(text, isNot(matches(arabic)), reason: text);
      }
      // A different message for each error.
      expect(arTexts.toSet(), hasLength(arTexts.length));
    });
  });

  test('a row of "profiles" becomes a UserProfile', () {
    final profile = UserProfile.fromRow({
      'id': 'b7c1',
      'phone': '+21650000001',
      'first_name': 'محمد',
      'last_name': 'بن سالم',
      'language': 'ar',
      'chosen_plan': 'essential',
      'payment_status': 'pending',
      'plan_chosen_at': '2026-10-28T10:00:00+00:00',
      'created_at': '2026-10-28T09:59:00+00:00',
    });
    expect(profile.fullName, 'محمد بن سالم');
    expect(profile.initial, 'م');
    expect(profile.chosenPlan, Plan.essential);
    expect(profile.paymentStatus, PaymentStatus.pending);
    expect(profile.hasName, isTrue);
    expect(profile.hasChosenPlan, isTrue);

    // Just created (the code was asked): no name, no pack yet.
    final fresh = UserProfile.fromRow({
      'id': 'b7c2',
      'phone': '+21650000003',
      'first_name': null,
      'last_name': null,
      'language': 'fr',
      'chosen_plan': 'free',
      'payment_status': 'free',
      'plan_chosen_at': null,
      'created_at': '2026-10-28T09:59:00+00:00',
    });
    expect(fresh.hasName, isFalse);
    expect(fresh.hasChosenPlan, isFalse);
    expect(fresh.role, UserRole.farmer);
    expect(fresh.hasSignUpInfo, isFalse);

    // The sign-up information (migrations 008 and 009).
    final expert = UserProfile.fromRow({
      'id': 'b7c3',
      'phone': '+21650000004',
      'first_name': 'Sami',
      'last_name': 'Dridi',
      'language': 'fr',
      'role': 'expert',
      'verified': false,
      'organisation': 'CRDA',
      'zone': 'sidi_bouzid',
      'almond_trees': 120,
      'orchard_area_ha': 2.5,
      'irrigation': 'rainfed',
      'chosen_plan': 'essential',
      'payment_status': 'pending',
      'plan_chosen_at': '2026-10-28T10:00:00+00:00',
      'created_at': '2026-10-28T09:59:00+00:00',
    });
    expect(expert.isExpert, isTrue);
    expect(expert.verified, isFalse);
    expect(expert.organisation, 'CRDA');
    expect(expert.governorate, 'sidi_bouzid');
    expect(expert.almondTrees, 120);
    expect(expert.orchardAreaHa, 2.5);
    expect(expert.irrigation, Irrigation.rainfed);
    expect(expert.hasSignUpInfo, isTrue);
    expect(expert.waitsForPayment, isTrue); // Essential chosen, not paid
    expect(fresh.language, 'fr');
  });
}
