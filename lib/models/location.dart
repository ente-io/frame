class Location {
  final double latitude;
  final double longitude;

  Location(this.latitude, this.longitude);

  @override
  String toString() => 'Location(latitude: $latitude, longitude: $longitude)';

  Map<String, dynamic> toJson() {
    return {
      "latitude": this.latitude,
      "longitude": this.latitude,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
    return Location(
        double.parse(map['latitude']), double.parse(map['latitude']));
  }
}
