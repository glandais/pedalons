// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'paired_device_type.dart';

part 'paired_device_dto.freezed.dart';
part 'paired_device_dto.g.dart';

/// A device (Karoo, Garmin) paired with the account by code, or an external application the user authorized through OAuth
@Freezed()
abstract class PairedDeviceDto with _$PairedDeviceDto {
  const factory PairedDeviceDto({
    /// Pairing ID, to unpair the device
    required String id,

    /// Kind of device. OTHER for an external application: applicationName then names it
    required String type,

    /// When the device was paired
    required String pairedAt,

    /// For an access opened through OAuth, the name the application gave itself (client_id) — unverified. Absent for a device.
    String? applicationName,

    /// When the device last renewed its access
    String? lastUsedAt,
  }) = _PairedDeviceDto;

  factory PairedDeviceDto.fromJson(Map<String, Object?> json) =>
      _$PairedDeviceDtoFromJson(json);
}
