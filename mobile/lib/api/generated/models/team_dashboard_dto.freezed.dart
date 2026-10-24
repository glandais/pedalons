// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'team_dashboard_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TeamDashboardDto {

/// The team, as GET /api/teams/{teamSlug} returns it — header, feature flags, memberCount; memberCountByRole is filled for an administrator.
 TeamDetailDto get team;/// The caller's real role in the team; null for a visitor, anonymous or not a member — a platform admin who is not a member included. The organizer and admin blocks are what a platform admin's rights add.
 String? get role;/// « Vos prochaines sorties »: the team's rides and trips starting from now that the caller is registered to, soonest first (at most 3). A ride row's registeredGroup is the group joined, with its pace. Null when both rides and trips are disabled, and for a visitor.
 PublicationListResponse? get myUpcoming;/// « Sorties à venir »: the team's published rides starting from now, soonest first (at most 3). Each row carries groupSummaries (fill per group), distance, elevationGain, surfaceType, registered and commentCount. Null when rides are disabled.
 PublicationListResponse? get upcomingRides;/// « Dernières publications »: the team's latest published posts, newest first (at most 3). Null when posts are disabled.
 PublicationListResponse? get latestPosts;/// « Nouveaux parcours »: the team's latest routes, newest first (at most 3). Null when routes are disabled.
 RouteListResponse? get newRoutes;/// « Annonces »: the team's latest ads, newest first (at most 3). A null price reads « Prix à négocier »; the place is locationDescription, a sector — never a pin. Null when ads are disabled, and for a visitor.
 AdListResponse? get latestAds;/// What organizers and administrators see on top. Null for a MEMBER and a visitor; filled for a platform admin, member or not.
 TeamDashboardOrganizerDto? get organizer;/// The administration panel. Null below ADMIN, and for a visitor; filled for a platform admin, member or not.
 TeamDashboardAdminDto? get admin;
/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeamDashboardDtoCopyWith<TeamDashboardDto> get copyWith => _$TeamDashboardDtoCopyWithImpl<TeamDashboardDto>(this as TeamDashboardDto, _$identity);

  /// Serializes this TeamDashboardDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TeamDashboardDto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeamDashboardDto&&(identical(other.team, _this.team) || other.team == _this.team)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.myUpcoming, _this.myUpcoming) || other.myUpcoming == _this.myUpcoming)&&(identical(other.upcomingRides, _this.upcomingRides) || other.upcomingRides == _this.upcomingRides)&&(identical(other.latestPosts, _this.latestPosts) || other.latestPosts == _this.latestPosts)&&(identical(other.newRoutes, _this.newRoutes) || other.newRoutes == _this.newRoutes)&&(identical(other.latestAds, _this.latestAds) || other.latestAds == _this.latestAds)&&(identical(other.organizer, _this.organizer) || other.organizer == _this.organizer)&&(identical(other.admin, _this.admin) || other.admin == _this.admin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TeamDashboardDto;
  return Object.hash(runtimeType,_this.team,_this.role,_this.myUpcoming,_this.upcomingRides,_this.latestPosts,_this.newRoutes,_this.latestAds,_this.organizer,_this.admin);
}

@override
String toString() {
  final _this = this as TeamDashboardDto;
  return 'TeamDashboardDto(team: ${_this.team}, role: ${_this.role}, myUpcoming: ${_this.myUpcoming}, upcomingRides: ${_this.upcomingRides}, latestPosts: ${_this.latestPosts}, newRoutes: ${_this.newRoutes}, latestAds: ${_this.latestAds}, organizer: ${_this.organizer}, admin: ${_this.admin})';
}


}

/// @nodoc
abstract mixin class $TeamDashboardDtoCopyWith<$Res>  {
  factory $TeamDashboardDtoCopyWith(TeamDashboardDto value, $Res Function(TeamDashboardDto) _then) = _$TeamDashboardDtoCopyWithImpl;
@useResult
$Res call({
 TeamDetailDto team, String? role, PublicationListResponse? myUpcoming, PublicationListResponse? upcomingRides, PublicationListResponse? latestPosts, RouteListResponse? newRoutes, AdListResponse? latestAds, TeamDashboardOrganizerDto? organizer, TeamDashboardAdminDto? admin
});


$TeamDetailDtoCopyWith<$Res> get team;$PublicationListResponseCopyWith<$Res>? get myUpcoming;$PublicationListResponseCopyWith<$Res>? get upcomingRides;$PublicationListResponseCopyWith<$Res>? get latestPosts;$RouteListResponseCopyWith<$Res>? get newRoutes;$AdListResponseCopyWith<$Res>? get latestAds;$TeamDashboardOrganizerDtoCopyWith<$Res>? get organizer;$TeamDashboardAdminDtoCopyWith<$Res>? get admin;

}
/// @nodoc
class _$TeamDashboardDtoCopyWithImpl<$Res>
    implements $TeamDashboardDtoCopyWith<$Res> {
  _$TeamDashboardDtoCopyWithImpl(this._self, this._then);

  final TeamDashboardDto _self;
  final $Res Function(TeamDashboardDto) _then;

/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? team = null,Object? role = freezed,Object? myUpcoming = freezed,Object? upcomingRides = freezed,Object? latestPosts = freezed,Object? newRoutes = freezed,Object? latestAds = freezed,Object? organizer = freezed,Object? admin = freezed,}) {
  return _then(TeamDashboardDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamDetailDto,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,myUpcoming: freezed == myUpcoming ? _self.myUpcoming : myUpcoming // ignore: cast_nullable_to_non_nullable
as PublicationListResponse?,upcomingRides: freezed == upcomingRides ? _self.upcomingRides : upcomingRides // ignore: cast_nullable_to_non_nullable
as PublicationListResponse?,latestPosts: freezed == latestPosts ? _self.latestPosts : latestPosts // ignore: cast_nullable_to_non_nullable
as PublicationListResponse?,newRoutes: freezed == newRoutes ? _self.newRoutes : newRoutes // ignore: cast_nullable_to_non_nullable
as RouteListResponse?,latestAds: freezed == latestAds ? _self.latestAds : latestAds // ignore: cast_nullable_to_non_nullable
as AdListResponse?,organizer: freezed == organizer ? _self.organizer : organizer // ignore: cast_nullable_to_non_nullable
as TeamDashboardOrganizerDto?,admin: freezed == admin ? _self.admin : admin // ignore: cast_nullable_to_non_nullable
as TeamDashboardAdminDto?,
  ));
}
/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDetailDtoCopyWith<$Res> get team {
  
  return $TeamDetailDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicationListResponseCopyWith<$Res>? get myUpcoming {
    if (_self.myUpcoming == null) {
    return null;
  }

  return $PublicationListResponseCopyWith<$Res>(_self.myUpcoming!, (value) {
    return _then(_self.copyWith(myUpcoming: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicationListResponseCopyWith<$Res>? get upcomingRides {
    if (_self.upcomingRides == null) {
    return null;
  }

  return $PublicationListResponseCopyWith<$Res>(_self.upcomingRides!, (value) {
    return _then(_self.copyWith(upcomingRides: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicationListResponseCopyWith<$Res>? get latestPosts {
    if (_self.latestPosts == null) {
    return null;
  }

  return $PublicationListResponseCopyWith<$Res>(_self.latestPosts!, (value) {
    return _then(_self.copyWith(latestPosts: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteListResponseCopyWith<$Res>? get newRoutes {
    if (_self.newRoutes == null) {
    return null;
  }

  return $RouteListResponseCopyWith<$Res>(_self.newRoutes!, (value) {
    return _then(_self.copyWith(newRoutes: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdListResponseCopyWith<$Res>? get latestAds {
    if (_self.latestAds == null) {
    return null;
  }

  return $AdListResponseCopyWith<$Res>(_self.latestAds!, (value) {
    return _then(_self.copyWith(latestAds: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDashboardOrganizerDtoCopyWith<$Res>? get organizer {
    if (_self.organizer == null) {
    return null;
  }

  return $TeamDashboardOrganizerDtoCopyWith<$Res>(_self.organizer!, (value) {
    return _then(_self.copyWith(organizer: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDashboardAdminDtoCopyWith<$Res>? get admin {
    if (_self.admin == null) {
    return null;
  }

  return $TeamDashboardAdminDtoCopyWith<$Res>(_self.admin!, (value) {
    return _then(_self.copyWith(admin: value));
  });
}
}


/// Adds pattern-matching-related methods to [TeamDashboardDto].
extension TeamDashboardDtoPatterns on TeamDashboardDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeamDashboardDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeamDashboardDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeamDashboardDto value)  $default,){
final _that = this;
switch (_that) {
case _TeamDashboardDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeamDashboardDto value)?  $default,){
final _that = this;
switch (_that) {
case _TeamDashboardDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TeamDetailDto team,  String? role,  PublicationListResponse? myUpcoming,  PublicationListResponse? upcomingRides,  PublicationListResponse? latestPosts,  RouteListResponse? newRoutes,  AdListResponse? latestAds,  TeamDashboardOrganizerDto? organizer,  TeamDashboardAdminDto? admin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeamDashboardDto() when $default != null:
return $default(_that.team,_that.role,_that.myUpcoming,_that.upcomingRides,_that.latestPosts,_that.newRoutes,_that.latestAds,_that.organizer,_that.admin);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TeamDetailDto team,  String? role,  PublicationListResponse? myUpcoming,  PublicationListResponse? upcomingRides,  PublicationListResponse? latestPosts,  RouteListResponse? newRoutes,  AdListResponse? latestAds,  TeamDashboardOrganizerDto? organizer,  TeamDashboardAdminDto? admin)  $default,) {final _that = this;
switch (_that) {
case _TeamDashboardDto():
return $default(_that.team,_that.role,_that.myUpcoming,_that.upcomingRides,_that.latestPosts,_that.newRoutes,_that.latestAds,_that.organizer,_that.admin);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TeamDetailDto team,  String? role,  PublicationListResponse? myUpcoming,  PublicationListResponse? upcomingRides,  PublicationListResponse? latestPosts,  RouteListResponse? newRoutes,  AdListResponse? latestAds,  TeamDashboardOrganizerDto? organizer,  TeamDashboardAdminDto? admin)?  $default,) {final _that = this;
switch (_that) {
case _TeamDashboardDto() when $default != null:
return $default(_that.team,_that.role,_that.myUpcoming,_that.upcomingRides,_that.latestPosts,_that.newRoutes,_that.latestAds,_that.organizer,_that.admin);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TeamDashboardDto implements TeamDashboardDto {
  const _TeamDashboardDto({required this.team, this.role, this.myUpcoming, this.upcomingRides, this.latestPosts, this.newRoutes, this.latestAds, this.organizer, this.admin});
  factory _TeamDashboardDto.fromJson(Map<String, dynamic> json) => _$TeamDashboardDtoFromJson(json);

/// The team, as GET /api/teams/{teamSlug} returns it — header, feature flags, memberCount; memberCountByRole is filled for an administrator.
@override final  TeamDetailDto team;
/// The caller's real role in the team; null for a visitor, anonymous or not a member — a platform admin who is not a member included. The organizer and admin blocks are what a platform admin's rights add.
@override final  String? role;
/// « Vos prochaines sorties »: the team's rides and trips starting from now that the caller is registered to, soonest first (at most 3). A ride row's registeredGroup is the group joined, with its pace. Null when both rides and trips are disabled, and for a visitor.
@override final  PublicationListResponse? myUpcoming;
/// « Sorties à venir »: the team's published rides starting from now, soonest first (at most 3). Each row carries groupSummaries (fill per group), distance, elevationGain, surfaceType, registered and commentCount. Null when rides are disabled.
@override final  PublicationListResponse? upcomingRides;
/// « Dernières publications »: the team's latest published posts, newest first (at most 3). Null when posts are disabled.
@override final  PublicationListResponse? latestPosts;
/// « Nouveaux parcours »: the team's latest routes, newest first (at most 3). Null when routes are disabled.
@override final  RouteListResponse? newRoutes;
/// « Annonces »: the team's latest ads, newest first (at most 3). A null price reads « Prix à négocier »; the place is locationDescription, a sector — never a pin. Null when ads are disabled, and for a visitor.
@override final  AdListResponse? latestAds;
/// What organizers and administrators see on top. Null for a MEMBER and a visitor; filled for a platform admin, member or not.
@override final  TeamDashboardOrganizerDto? organizer;
/// The administration panel. Null below ADMIN, and for a visitor; filled for a platform admin, member or not.
@override final  TeamDashboardAdminDto? admin;

/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeamDashboardDtoCopyWith<_TeamDashboardDto> get copyWith => __$TeamDashboardDtoCopyWithImpl<_TeamDashboardDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeamDashboardDtoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeamDashboardDto&&(identical(other.team, team) || other.team == team)&&(identical(other.role, role) || other.role == role)&&(identical(other.myUpcoming, myUpcoming) || other.myUpcoming == myUpcoming)&&(identical(other.upcomingRides, upcomingRides) || other.upcomingRides == upcomingRides)&&(identical(other.latestPosts, latestPosts) || other.latestPosts == latestPosts)&&(identical(other.newRoutes, newRoutes) || other.newRoutes == newRoutes)&&(identical(other.latestAds, latestAds) || other.latestAds == latestAds)&&(identical(other.organizer, organizer) || other.organizer == organizer)&&(identical(other.admin, admin) || other.admin == admin));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,team,role,myUpcoming,upcomingRides,latestPosts,newRoutes,latestAds,organizer,admin);
}

@override
String toString() {
    return 'TeamDashboardDto(team: $team, role: $role, myUpcoming: $myUpcoming, upcomingRides: $upcomingRides, latestPosts: $latestPosts, newRoutes: $newRoutes, latestAds: $latestAds, organizer: $organizer, admin: $admin)';
}


}

/// @nodoc
abstract mixin class _$TeamDashboardDtoCopyWith<$Res> implements $TeamDashboardDtoCopyWith<$Res> {
  factory _$TeamDashboardDtoCopyWith(_TeamDashboardDto value, $Res Function(_TeamDashboardDto) _then) = __$TeamDashboardDtoCopyWithImpl;
@override @useResult
$Res call({
 TeamDetailDto team, String? role, PublicationListResponse? myUpcoming, PublicationListResponse? upcomingRides, PublicationListResponse? latestPosts, RouteListResponse? newRoutes, AdListResponse? latestAds, TeamDashboardOrganizerDto? organizer, TeamDashboardAdminDto? admin
});


@override $TeamDetailDtoCopyWith<$Res> get team;@override $PublicationListResponseCopyWith<$Res>? get myUpcoming;@override $PublicationListResponseCopyWith<$Res>? get upcomingRides;@override $PublicationListResponseCopyWith<$Res>? get latestPosts;@override $RouteListResponseCopyWith<$Res>? get newRoutes;@override $AdListResponseCopyWith<$Res>? get latestAds;@override $TeamDashboardOrganizerDtoCopyWith<$Res>? get organizer;@override $TeamDashboardAdminDtoCopyWith<$Res>? get admin;

}
/// @nodoc
class __$TeamDashboardDtoCopyWithImpl<$Res>
    implements _$TeamDashboardDtoCopyWith<$Res> {
  __$TeamDashboardDtoCopyWithImpl(this._self, this._then);

  final _TeamDashboardDto _self;
  final $Res Function(_TeamDashboardDto) _then;

/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? team = null,Object? role = freezed,Object? myUpcoming = freezed,Object? upcomingRides = freezed,Object? latestPosts = freezed,Object? newRoutes = freezed,Object? latestAds = freezed,Object? organizer = freezed,Object? admin = freezed,}) {
  return _then(_TeamDashboardDto(
team: null == team ? _self.team : team // ignore: cast_nullable_to_non_nullable
as TeamDetailDto,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,myUpcoming: freezed == myUpcoming ? _self.myUpcoming : myUpcoming // ignore: cast_nullable_to_non_nullable
as PublicationListResponse?,upcomingRides: freezed == upcomingRides ? _self.upcomingRides : upcomingRides // ignore: cast_nullable_to_non_nullable
as PublicationListResponse?,latestPosts: freezed == latestPosts ? _self.latestPosts : latestPosts // ignore: cast_nullable_to_non_nullable
as PublicationListResponse?,newRoutes: freezed == newRoutes ? _self.newRoutes : newRoutes // ignore: cast_nullable_to_non_nullable
as RouteListResponse?,latestAds: freezed == latestAds ? _self.latestAds : latestAds // ignore: cast_nullable_to_non_nullable
as AdListResponse?,organizer: freezed == organizer ? _self.organizer : organizer // ignore: cast_nullable_to_non_nullable
as TeamDashboardOrganizerDto?,admin: freezed == admin ? _self.admin : admin // ignore: cast_nullable_to_non_nullable
as TeamDashboardAdminDto?,
  ));
}

/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDetailDtoCopyWith<$Res> get team {
  
  return $TeamDetailDtoCopyWith<$Res>(_self.team, (value) {
    return _then(_self.copyWith(team: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicationListResponseCopyWith<$Res>? get myUpcoming {
    if (_self.myUpcoming == null) {
    return null;
  }

  return $PublicationListResponseCopyWith<$Res>(_self.myUpcoming!, (value) {
    return _then(_self.copyWith(myUpcoming: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicationListResponseCopyWith<$Res>? get upcomingRides {
    if (_self.upcomingRides == null) {
    return null;
  }

  return $PublicationListResponseCopyWith<$Res>(_self.upcomingRides!, (value) {
    return _then(_self.copyWith(upcomingRides: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PublicationListResponseCopyWith<$Res>? get latestPosts {
    if (_self.latestPosts == null) {
    return null;
  }

  return $PublicationListResponseCopyWith<$Res>(_self.latestPosts!, (value) {
    return _then(_self.copyWith(latestPosts: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RouteListResponseCopyWith<$Res>? get newRoutes {
    if (_self.newRoutes == null) {
    return null;
  }

  return $RouteListResponseCopyWith<$Res>(_self.newRoutes!, (value) {
    return _then(_self.copyWith(newRoutes: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AdListResponseCopyWith<$Res>? get latestAds {
    if (_self.latestAds == null) {
    return null;
  }

  return $AdListResponseCopyWith<$Res>(_self.latestAds!, (value) {
    return _then(_self.copyWith(latestAds: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDashboardOrganizerDtoCopyWith<$Res>? get organizer {
    if (_self.organizer == null) {
    return null;
  }

  return $TeamDashboardOrganizerDtoCopyWith<$Res>(_self.organizer!, (value) {
    return _then(_self.copyWith(organizer: value));
  });
}/// Create a copy of TeamDashboardDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TeamDashboardAdminDtoCopyWith<$Res>? get admin {
    if (_self.admin == null) {
    return null;
  }

  return $TeamDashboardAdminDtoCopyWith<$Res>(_self.admin!, (value) {
    return _then(_self.copyWith(admin: value));
  });
}
}

// dart format on
