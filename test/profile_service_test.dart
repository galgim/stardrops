import 'package:flutter_test/flutter_test.dart';
import 'package:stardrop/services/profile_service.dart';

/// `clean` is the only branching logic in the profile, and it guards two very
/// different doors: what the player types, and (once there's a network) what
/// another phone claims its name is. Both are covered by the same cases.
void main() {
  test('blank names fall back to the default', () {
    expect(ProfileService.clean(null), ProfileService.defaultName);
    expect(ProfileService.clean(''), ProfileService.defaultName);
    expect(ProfileService.clean('   '), ProfileService.defaultName);
  });

  test('surrounding whitespace is trimmed', () {
    expect(ProfileService.clean('  Clay  '), 'Clay');
  });

  test('an over-long name is capped rather than rejected', () {
    final long = 'A' * 100;
    expect(ProfileService.clean(long).length, ProfileService.maxLength);
  });

  test('a name at exactly the cap is left alone', () {
    final exact = 'A' * ProfileService.maxLength;
    expect(ProfileService.clean(exact), exact);
  });
}
