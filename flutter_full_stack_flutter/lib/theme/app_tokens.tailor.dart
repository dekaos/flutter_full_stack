// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_tokens.dart';

// **************************************************************************
// TailorAnnotationsGenerator
// **************************************************************************

mixin _$AppTokensTailorMixin on ThemeExtension<AppTokens> {
  Color get backdropTop;
  Color get backdropBottom;
  Color get glassTint;
  Color get glassBorder;
  Color get glassHighlight;
  double get glassBlur;
  double get radiusLarge;
  double get radiusMedium;
  Color get auroraOne;
  Color get auroraTwo;
  Color get auroraThree;

  @override
  AppTokens copyWith({
    Color? backdropTop,
    Color? backdropBottom,
    Color? glassTint,
    Color? glassBorder,
    Color? glassHighlight,
    double? glassBlur,
    double? radiusLarge,
    double? radiusMedium,
    Color? auroraOne,
    Color? auroraTwo,
    Color? auroraThree,
  }) {
    return AppTokens(
      backdropTop: backdropTop ?? this.backdropTop,
      backdropBottom: backdropBottom ?? this.backdropBottom,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassBlur: glassBlur ?? this.glassBlur,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      auroraOne: auroraOne ?? this.auroraOne,
      auroraTwo: auroraTwo ?? this.auroraTwo,
      auroraThree: auroraThree ?? this.auroraThree,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this as AppTokens;
    return AppTokens(
      backdropTop: Color.lerp(backdropTop, other.backdropTop, t)!,
      backdropBottom: Color.lerp(backdropBottom, other.backdropBottom, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      glassBlur: t < 0.5 ? glassBlur : other.glassBlur,
      radiusLarge: t < 0.5 ? radiusLarge : other.radiusLarge,
      radiusMedium: t < 0.5 ? radiusMedium : other.radiusMedium,
      auroraOne: Color.lerp(auroraOne, other.auroraOne, t)!,
      auroraTwo: Color.lerp(auroraTwo, other.auroraTwo, t)!,
      auroraThree: Color.lerp(auroraThree, other.auroraThree, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AppTokens &&
            const DeepCollectionEquality().equals(
              backdropTop,
              other.backdropTop,
            ) &&
            const DeepCollectionEquality().equals(
              backdropBottom,
              other.backdropBottom,
            ) &&
            const DeepCollectionEquality().equals(glassTint, other.glassTint) &&
            const DeepCollectionEquality().equals(
              glassBorder,
              other.glassBorder,
            ) &&
            const DeepCollectionEquality().equals(
              glassHighlight,
              other.glassHighlight,
            ) &&
            const DeepCollectionEquality().equals(glassBlur, other.glassBlur) &&
            const DeepCollectionEquality().equals(
              radiusLarge,
              other.radiusLarge,
            ) &&
            const DeepCollectionEquality().equals(
              radiusMedium,
              other.radiusMedium,
            ) &&
            const DeepCollectionEquality().equals(auroraOne, other.auroraOne) &&
            const DeepCollectionEquality().equals(auroraTwo, other.auroraTwo) &&
            const DeepCollectionEquality().equals(
              auroraThree,
              other.auroraThree,
            ));
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType.hashCode,
      const DeepCollectionEquality().hash(backdropTop),
      const DeepCollectionEquality().hash(backdropBottom),
      const DeepCollectionEquality().hash(glassTint),
      const DeepCollectionEquality().hash(glassBorder),
      const DeepCollectionEquality().hash(glassHighlight),
      const DeepCollectionEquality().hash(glassBlur),
      const DeepCollectionEquality().hash(radiusLarge),
      const DeepCollectionEquality().hash(radiusMedium),
      const DeepCollectionEquality().hash(auroraOne),
      const DeepCollectionEquality().hash(auroraTwo),
      const DeepCollectionEquality().hash(auroraThree),
    );
  }
}

extension AppTokensThemeData on ThemeData {
  AppTokens get appTokens => extension<AppTokens>()!;
}
