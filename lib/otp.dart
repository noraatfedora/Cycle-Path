import 'package:http/http.dart' as http;
import 'dart:convert';

const serverUrl = 'otp.prod.sound.obaweb.org';

class OpenTripPlannerWrapper {
  static Future<List> getItineraries(Map<String, dynamic> params) async {
    var uri = Uri.https(serverUrl, '/otp/routers/default/plan', params);
    print("uri: $uri");
    final jsonResponse = await http.get(uri);
    final body = json.decode(jsonResponse.body);
    final itineraries = body['plan']['itineraries'];
    return itineraries;
  }
}
/*
class Trip {
  late int startTime;
  late int endTime;
  late int transfers;
  late List<Leg> legs;

  Trip(Map<String, dynamic> response) {
    startTime = response['startTime'];
    endTime = response['endTime'];
    transfers = response['transfers'];
    legsResponse = response['legs'];
    for (leg in legsResponse) {
      legs.add(Leg(leg));
    }
  }
}

class Place {
  late final String name;
  late final double lat;
  late final double lon;

  Place(Map<String, dynamic> response) {
    name = response['name'];
    lat = response['lat'];
    lon = response['lon'];
  }
}

class Leg {
  late int startTime;
  late int endTime;
  late String mode;
  late double distance;
  late Place from;
  late Place to;

  Leg(Map<String, dynamic> response) {
    startTime = response['startTime'];
    endTime = response['endTime'];
    mode = response['mode'];
    distance = response['distance'];
    from = Place(response['from']);
    to = Place(response['to']);
  }
}

void main(List<String> args) {
  OpenTripPlannerWrapper.getTrips({
    "fromPlace": "47.638184,-122.159497",
    "toPlace": "47.620937,-122.297215",
  });
}
*/