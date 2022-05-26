// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:biking_to_the_bus_stop/otp.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_place/google_place.dart';
import 'package:intl/intl.dart';

Future main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gongle Naps',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Gongle Naps'),
        ),
        body: Center(
          child: TripPlannerForm(),
        ),
      ),
    );
  }
}

class LatLong {
  double lat;
  double lon;

  LatLong(this.lat, this.lon);

  String toString() => '$lat,$lon';
}

class TripPlannerForm extends StatefulWidget {
  TripPlannerForm({Key? key}) : super(key: key);

  @override
  State<TripPlannerForm> createState() => TripPlannerFormState();
}

class TripPlannerFormState extends State<TripPlannerForm> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final LatLong _fromLoc = LatLong(0.0, 0.0);
  final _toController = TextEditingController();
  final LatLong _toLoc = LatLong(0.0, 0.0);
  late GooglePlace googlePlace;
  List<AutocompletePrediction> predictions = [];

  @override
  void initState() {
    String apiKey = dotenv.env['GOOGLE_API_KEY'].toString();
    googlePlace = GooglePlace(apiKey);
  }

  @override
  Widget build(BuildContext context) {
    const formPadding = EdgeInsets.all(16.0);
    return Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            Padding(
              padding: formPadding,
              child: googleAutocompleteFormField(
                  _fromController, _fromLoc, "From", "Where are you starting?"),
            ),
            Padding(
              padding: formPadding,
              child: googleAutocompleteFormField(
                  _toController, _toLoc, "To", "Where are you going?"),
            ),
            ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState != null &&
                      _formKey.currentState!.validate()) {
                    // If the form is valid, display a Snackbar.
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('loading routes...')));
                    /*
                    final itinerariesFuture =
                        OpenTripPlannerWrapper.getItineraries({
                      "fromPlace": "47.638184,-122.159497",
                      "toPlace": "47.620937,-122.297215",
                    });
                    */
                    final itinerariesFuture =
                        OpenTripPlannerWrapper.getItineraries({
                      "fromPlace": _fromLoc.toString(),
                      "toPlace": _toLoc.toString(),
                      "mode": "TRANSIT, BICYCLE",
                      "optimize": "TRANSFERS",
                    });
                    itinerariesFuture.then((value) {
                      //_ItinerariesViewerState.setText(itineraries);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => resultsPage(value)));
                    });
                  }
                },
                child: const Text('Submit'))
          ],
        ));
  }

  double metersToMiles(double meters) {
    return meters * 0.000621371;
  }

  ListTile renderLeg(Map<String, dynamic> leg) {
    final icons = {
      "WALK": Icons.directions_walk,
      "BICYCLE": Icons.directions_bike,
      "TRANSIT": Icons.directions_bus,
      "FERRY": Icons.directions_boat,
      "RAIL": Icons.directions_railway,
      "SUBWAY": Icons.directions_subway,
      "TRAIN": Icons.directions_transit,
      "BUS": Icons.directions_bus,
      "TRAM": Icons.directions_subway,
    };
    late IconData icon;
    if (icons.containsKey(leg["mode"])) {
      icon = icons[leg["mode"]]!;
    } else {
      icon = Icons.directions_transit;
    }

    late String subtitle;
    String prettyDistance =
        "${metersToMiles(leg['distance']!).toStringAsFixed(1)} miles";
    // if distance is less than 0.1 miles, display distance in feet
    if (metersToMiles(leg['distance']!) < 0.1) {
      // convert meters to feet
      prettyDistance =
          "${(leg['distance']! * 3.28084).toStringAsFixed(0)} feet";
    }
    String minutes = (leg['duration']! ~/ 60).toString();
    String distanceInfo = '$prettyDistance | $minutes minutes';
    if (leg['transitLeg']) {
      if (leg.containsKey('routeShortName')) {
        if (leg.containsKey('headsign')) {
          subtitle = '${leg["routeShortName"]}: ${leg["headsign"]}';
        } else {
          subtitle = '${leg["routeShortName"]}';
        }
      } else {
        if (leg.containsKey('headsign')) {
          subtitle = '${leg["headsign"]}';
        } else {
          subtitle = '${leg["mode"]}';
        }
      }
    } else {
      String verb = 'Bike';
      if (leg['mode'] != 'BICYCLE') {
        // convert the leg mode to start with an
        // uppercase letter
        verb = leg['mode'][0].toUpperCase() +
            leg['mode'].toLowerCase().substring(1);
      }
      subtitle = "${verb} ${distanceInfo}";
    }

    if (leg['transitLeg']) {
      return ListTile(
        leading: Icon(icon),
        title: Text(leg['from']['name']),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_rounded),
      );
    } else {
      return ListTile(
        leading: Icon(icon),
        title: Text(leg['from']['name']),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_rounded),
      );
    }
  }

  Widget googleAutocompleteFormField(TextEditingController controller,
      LatLong loc, String labelText, String hintText) {
    return TypeAheadFormField(
      textFieldConfiguration: TextFieldConfiguration(
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          border: UnderlineInputBorder(),
        ),
        controller: controller,
      ),
      suggestionsCallback: (pattern) async {
        if (pattern != null && pattern.isNotEmpty) {
          var result = await googlePlace.autocomplete.get(pattern);
          if (result != null) {
            return result.predictions!;
          }
        }
        return <AutocompletePrediction>[];
      },
      itemBuilder: (context, AutocompletePrediction suggestion) {
        return ListTile(
          title: Text(suggestion.description!),
        );
      },
      transitionBuilder: (context, suggestionsBox, controller) {
        return suggestionsBox;
      },
      onSuggestionSelected: (AutocompletePrediction suggestion) async {
        controller.text = suggestion.description!;
        DetailsResponse? detailsResult =
            await googlePlace.details.get(suggestion.placeId!);
        if (detailsResult != null) {
          loc.lat = detailsResult.result!.geometry!.location!.lat!;
          loc.lon = detailsResult.result!.geometry!.location!.lng!;
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a location';
        }
        return null;
      },
    );
  }

  Widget resultsPage(List<dynamic> itineraries) {
    var tabChildren = <Widget>[];
    var tabTitles = <Widget>[];
    // iterate through itineraries
    for (var i = 0; i < itineraries.length; i++) {
      var itinerary = itineraries[i];
      var durationString = '';
      if (itinerary['duration'] > 3600) {
        // more than an hour
        durationString = '${(itinerary['duration'] / 3600).floor()} hours, ';
      }
      durationString += '${(itinerary['duration'] % 3600) ~/ 60} minutes';
      tabTitles.add(Column(
        children: [
          Text(durationString),
          Text(convertUnixToReadable(itinerary['startTime'])),
          Text(convertUnixToReadable(itinerary["endTime"])),
        ],
      ));
      final legsChildren = <Widget>[];
      // iterate through itinerary legs
      for (var j = 0; j < itinerary['legs'].length; j++) {
        var leg = itinerary['legs'][j];
        legsChildren.add(renderLeg(leg));
      }
      var legs = ListView(
        children: legsChildren,
      );

      tabChildren.add(legs);
    }
    final tabController = DefaultTabController(
      length: itineraries.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Results'),
          bottom: TabBar(tabs: tabTitles),
        ),
        body: TabBarView(
          children: tabChildren,
        ),
      ),
    );
    //return Scaffold(appBar: AppBar(title: const Text('Results')), body: ta);
    return tabController;
  }

  String convertUnixToReadable(int unixTime) {
    var date = DateTime.fromMillisecondsSinceEpoch(unixTime * 1000);
    return DateFormat('hh:mm a').format(date);
  }

  void autoCompleteSearch(String value) async {
    var result = await googlePlace.autocomplete.get(value);
    if (result != null && result.predictions != null && mounted) {
      setState(() {
        predictions = result.predictions!;
      });
    }
    ;
  }
}
