enum GenderOption { female, male, other, preferNotToSay }

extension GenderOptionDetails on GenderOption {
  String get dbValue => switch (this) {
    GenderOption.female => 'female',
    GenderOption.male => 'male',
    GenderOption.other => 'other',
    GenderOption.preferNotToSay => 'prefer_not_to_say',
  };

  String get label => switch (this) {
    GenderOption.female => 'Kadın',
    GenderOption.male => 'Erkek',
    GenderOption.other => 'Diğer',
    GenderOption.preferNotToSay => 'Belirtmek istemiyorum',
  };
}

GenderOption? genderOptionFromDbValue(Object? value) {
  final raw = value?.toString();
  for (final option in GenderOption.values) {
    if (option.dbValue == raw) return option;
  }
  return null;
}

class ProfileSettings {
  const ProfileSettings({
    required this.displayName,
    required this.bio,
    required this.city,
    required this.district,
    required this.receiveCategoryIds,
    required this.provideCategoryIds,
    this.gender,
    this.avatarUrl,
  });

  final String displayName;
  final String bio;
  final String city;
  final String district;
  final GenderOption? gender;
  final String? avatarUrl;
  final Set<String> receiveCategoryIds;
  final Set<String> provideCategoryIds;
}
