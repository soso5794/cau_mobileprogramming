/// Optional coordinates for a confirmed meeting place. Old text-only posts remain valid.
class RecruitmentLocation {
  const RecruitmentLocation({required this.name, required this.latitude,
    required this.longitude, this.address = ''});
  final String name, address;
  final double latitude, longitude;
  bool get isValid => name.trim().isNotEmpty && name.length <= 120 &&
    address.length <= 300 && latitude.isFinite && longitude.isFinite &&
    latitude >= -85.05112878 && latitude <= 85.05112878 && longitude >= -180 && longitude <= 180;
  Map<String, dynamic> toJson() => {'name': name, 'address': address,
    'latitude': latitude, 'longitude': longitude};
  factory RecruitmentLocation.fromJson(Map<String, dynamic> j) => RecruitmentLocation(
    name: j['name'] as String, address: j['address'] as String? ?? '',
    latitude: (j['latitude'] as num).toDouble(), longitude: (j['longitude'] as num).toDouble());
}
