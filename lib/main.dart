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
import 'package:date_time_picker/date_time_picker.dart';
import 'package:scroll_app_bar/scroll_app_bar.dart';

Future main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

final String googleApiKey = dotenv.env['GOOGLE_API_KEY'].toString();
final GooglePlace googlePlace = GooglePlace(googleApiKey);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cycle Path',
      home: Scaffold(
        appBar: AppBar(
          leading: const Icon(Icons.directions_bike),
          title: const Text('Cycle Path'),
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
  String fancyName;

  LatLong(this.lat, this.lon, this.fancyName);

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
  final LatLong _fromLoc = LatLong(0.0, 0.0, 'Origin');
  final _toController = TextEditingController();
  final LatLong _toLoc = LatLong(0.0, 0.0, 'Destination');
  DateTime _timeController = DateTime.now();
  String leavingArrivingDropdownValue = 'Leaving now';
  List<AutocompletePrediction> predictions = [];

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
            Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: DropdownButton<String>(
                value: leavingArrivingDropdownValue,
                icon: const Icon(Icons.arrow_downward),
                elevation: 16,
                //style: const TextStyle(color: Colors.deepPurple),
                underline: Container(
                  height: 2,
                  color: Colors.deepPurpleAccent,
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    leavingArrivingDropdownValue = newValue!;
                  });
                },
                items: <String>['Leaving now', 'Leave at', 'Arrive by']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
            Visibility(
              visible: leavingArrivingDropdownValue != 'Leaving now',
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: DateTimePicker(
                      type: DateTimePickerType.dateTimeSeparate,
                      initialValue: DateTime.now().toString(),
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2100),
                      icon: const Icon(Icons.calendar_today),
                      dateLabelText: 'Date',
                      timeLabelText: 'Time',
                      onChanged: (val) {
                        _timeController = DateTime.parse(val);
                      })),
            ),

            //onSaved: (val) => print(val)),
            Padding(
                padding: formPadding,
                child: ElevatedButton(
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
                        Map<String, String> params = {
                          "fromPlace": _fromLoc.toString(),
                          "toPlace": _toLoc.toString(),
                          "mode": "TRANSIT, BICYCLE",
                          "optimize": "TRANSFERS",
                          //"time": (DateTime.now().millisecondsSinceEpoch / 1000)
                          //    .toString(),
                          "arriveBy":
                              (leavingArrivingDropdownValue == 'Arrive by')
                                  .toString(),
                          "showIntermediateStops": "true",
                          "maxWalkDistance": "99999999999",
                        };
                        if (leavingArrivingDropdownValue != 'Leaving now') {
                          params['time'] =
                              "${_timeController.hour}:${_timeController.minute}";
                          params['date'] =
                              "${_timeController.year}-${_timeController.month}-${_timeController.day}";
                        }

                        final itinerariesFuture =
                            OpenTripPlannerWrapper.getItineraries(params);
                        itinerariesFuture.then((value) {
                          //_ItinerariesViewerState.setText(itineraries);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ResultsPage(
                                  plan: value,
                                  startLoc: _fromLoc,
                                  endLoc: _toLoc,
                                  query: params)));
                        });
                      }
                    },
                    child: const Text('Submit')))
          ],
        ));
  }
}

double metersToMiles(double meters) {
  return meters * 0.000621371;
}

String getPrettyDistance(double meters) {
  String prettyDistance = "${metersToMiles(meters).toStringAsFixed(1)} miles";
  // if distance is less than 0.1 miles, display distance in feet
  if (metersToMiles(meters) < 0.1) {
    // convert meters to feet
    prettyDistance = "${(meters! * 3.28084).toStringAsFixed(0)} feet";
  }
  return prettyDistance;
}

String getFancyRouteName(leg) {
  late String transitInfo;
  if (leg.containsKey('routeShortName')) {
    if (leg.containsKey('headsign')) {
      transitInfo = '${leg["routeShortName"]}: ${leg["headsign"]}';
    } else {
      transitInfo = '${leg["routeShortName"]}';
    }
  } else {
    if (leg.containsKey('headsign')) {
      transitInfo = '${leg["headsign"]}';
    } else {
      transitInfo = '${leg["mode"]}';
    }
  }
  return transitInfo;
}

IconData getIconFromMode(String mode) {
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
  if (icons.containsKey(mode)) {
    icon = icons[mode]!;
  } else {
    icon = Icons.directions_transit;
  }
  return icon;
}

class LegOverview extends StatelessWidget {
  //  const LegOverview({Key? key}) : super(key: key);
  final leg;
  const LegOverview(this.leg);

  @override
  Widget build(BuildContext context) {
    String prettyDistance = getPrettyDistance(leg['distance']!);
    String minutes = (leg['duration']! ~/ 60).toString();
    String distanceInfo = '$prettyDistance | $minutes minutes';
    late String title;
    late String subtitle;
    final Widget onTap;
    if (leg['transitLeg']) {
      title = "Get on ${leg["agencyName"]} ${getFancyRouteName(leg)}";
      subtitle = distanceInfo;
      onTap = TransitLegDetails(leg);
    } else {
      String verb = 'Bike';
      if (leg['mode'] != 'BICYCLE') {
        // convert the leg mode to start with an
        // uppercase letter
        verb = leg['mode'][0].toUpperCase() +
            leg['mode'].toLowerCase().substring(1);
      }
      title = "$verb from ${leg['from']['name']} to ${leg["to"]["name"]}";
      subtitle = distanceInfo;
      onTap = NonTransitLegDetails(leg);
    }
    return ListTile(
      leading: Icon(getIconFromMode(leg['mode'])),
      title: RichText(
        text: TextSpan(
          // display the title and the time
          children: [
            TextSpan(
                text: '${convertUnixToReadable(leg["startTime"]).toString()}',
                style: TextStyle(
                    fontSize: 14.0, color: Colors.black.withOpacity(0.5))),
            TextSpan(
                text: '\n$title',
                style: TextStyle(fontSize: 18.0, color: Colors.black)),
          ],
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => onTap,
        ),
      ),
    );
  }
}

class TransitLegDetails extends StatelessWidget {
  final leg;
  const TransitLegDetails(this.leg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(getFancyRouteName(leg)),
        ),
        body: ListView.builder(
            itemCount: leg["intermediateStops"].length,
            itemBuilder: (context, index) {
              return TransitStop(leg['intermediateStops'][index], leg['mode']);
            }));
  }
}

class TransitStop extends StatelessWidget {
  final stop;
  final mode;
  const TransitStop(this.stop, this.mode);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(getIconFromMode(mode)),
      title: Text(stop['name']),
      subtitle: Text(convertUnixToReadable(stop['arrival'])),
    );
  }
}

class NonTransitLegDetails extends StatelessWidget {
  final leg;
  const NonTransitLegDetails(this.leg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getFancyRouteName(leg)),
      ),
      body: ListView.builder(
        itemCount: leg["steps"].length,
        itemBuilder: (BuildContext context, int index) {
          return WalkStep(leg['steps'][index], leg['mode']);
        },
      ),
    );
  }
}

IconData getIconFromDirection(String direction, String mode) {
  final icons = {
    "LEFT": Icons.turn_left,
    "HARD_LEFT": Icons.turn_sharp_left,
    "SLIGHTLY_LEFT": Icons.turn_slight_left,
    "RIGHT": Icons.turn_right,
    "HARD_RIGHT": Icons.turn_sharp_right,
    "SLIGHTLY_RIGHT": Icons.turn_slight_right,
    "CONTINUE": Icons.arrow_upward_rounded,
    "ELEVATOR": Icons.elevator,
    "UTURN_LEFT": Icons.u_turn_left,
    "UTURN_RIGHT": Icons.u_turn_right,
  };
  if (icons.containsKey(direction)) {
    return icons[direction]!;
  } else {
    if (mode == 'BICYCLE') {
      return Icons.directions_bike;
    } else if (mode == 'WALK') {
      return Icons.directions_walk;
    } else {
      return Icons.arrow_forward_rounded;
    }
  }
}

String getFriendlyDirection(String direction) {
  final directions = {
    "DEPART": "Depart from",
    "LEFT": "Turn left onto",
    "HARD_LEFT": "Make a hard left onto",
    "SLIGHTLY_LEFT": "Turn slightly left onto",
    "RIGHT": "Turn right onto",
    "HARD_RIGHT": "Make a hard right onto",
    "SLIGHTLY_RIGHT": "Turn slightly right onto",
    "CONTINUE": "Continue onto",
    "ELEVATOR": "Take the elevator to",
    "UTURN_LEFT": "Make a U-turn left onto",
    "UTURN_RIGHT": "Make a U-turn right onto",
    "CIRCLE_CLOCKWISE": "Take a circle clockwise onto",
    "CIRLCE_COUNTERCLOCKWISE": "Take a circle counterclockwise onto",
  };
  if (directions.containsKey(direction)) {
    return directions[direction]!;
  } else {
    return "";
  }
}

class WalkStep extends StatelessWidget {
  final data;
  final mode;
  const WalkStep(this.data, this.mode);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(getIconFromDirection(data['relativeDirection'], mode)),
      title: Text(
          '${getFriendlyDirection(data['relativeDirection'])} ${data['streetName']}'),
      subtitle: Text(getPrettyDistance(data["distance"])),
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
        loc.fancyName = detailsResult.result!.name!;
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

String getPrettyTime(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secondsLeft = seconds % 60;
  final hoursString =
      hours == 0 ? "" : (minutes > 0 ? "$hours hours, " : "$hours hours");
  final minutesString = minutes == 0 ? "" : "$minutes minutes ";
  return "$hoursString$minutesString";
}

class ResultsPage extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic> query;
  LatLong startLoc;
  LatLong endLoc;
  final scrollController = ScrollController();
  ResultsPage(
      {Key? key,
      required this.plan,
      required this.startLoc,
      required this.endLoc,
      required this.query});

  @override
  Widget build(BuildContext context) {
    List<dynamic> itineraries = plan['itineraries'];
    var tabChildren = <Widget>[];
    var tabTitles = <Widget>[];
    // iterate through itineraries
    for (var i = 0; i < itineraries.length; i++) {
      var itinerary = itineraries[i];
      final durationString = getPrettyTime(itinerary['duration']);
      tabTitles.add(Column(
        children: [
          Text(durationString),
          Text(
              "${convertUnixToReadable(itinerary['startTime'])}-${convertUnixToReadable(itinerary['endTime'])}"),
        ],
      ));
      final legsChildren = <Widget>[
        ItineraryStats(itinerary: itinerary, query: query)
      ];
      // iterate through itinerary legs
      for (var j = 0; j < itinerary['legs'].length; j++) {
        var leg = itinerary['legs'][j];
        legsChildren.add(LegOverview(leg));
      }
      var legs = ListView(
        controller: scrollController,
        children: legsChildren,
      );

      tabChildren.add(legs);
    }
    final tabController = DefaultTabController(
      length: itineraries.length,
      child: Scaffold(
        appBar: ScrollAppBar(
          controller: scrollController,
          title: Flexible(
              child: Column(children: [
            Align(
                alignment: Alignment.topLeft,
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Text('Results'))),
            Align(
              alignment: Alignment.topLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: startLoc.fancyName,
                    ),
                    WidgetSpan(
                        child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            child:
                                Icon(Icons.arrow_forward_rounded, size: 17))),
                    TextSpan(
                      text: endLoc.fancyName,
                    ),
                  ],
                ),
              ),
            )
          ])),
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
}

class SaveableItinerary {
  final LatLong startLoc;
  final LatLong endLoc;
  final Map<String, dynamic> itinerary;
  final Map<String, dynamic> query;
  final bool isSaved = false;
  SaveableItinerary(
      {required this.startLoc,
      required this.endLoc,
      required this.itinerary,
      required this.query});
}

class ItineraryStats extends StatefulWidget {
  final Map<String, dynamic> itinerary;
  final Map<String, dynamic> query;

  ItineraryStats({Key? key, required this.itinerary, required this.query})
      : super(key: key);
  bool saved = false;

  @override
  State<ItineraryStats> createState() => _ItineraryStatsState();
}

class _ItineraryStatsState extends State<ItineraryStats> {
  bool saved;

  bool toggleSaved() {
    setState(() {
      saved = !saved;
    });
    return saved;
  }

  _ItineraryStatsState({this.saved = false});
  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> itinerary = widget.itinerary;
    Map<String, dynamic> query = widget.query;
    bool cyclingEnabled = true; // TODO: get this from query

    String transferText = "";
    if (itinerary['transfers'] > 0) {
      transferText =
          "${itinerary['transfers']} transfer${itinerary['transfers'] > 1 ? "s" : ""}\n";
    }
    return Card(
      child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                  child: Align(
                      alignment: Alignment.topLeft,
                      child: RichText(
                          text: TextSpan(children: [
                        WidgetSpan(
                            child: Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Icon(
                                  getIconFromMode(
                                      cyclingEnabled ? 'BICYCLE' : 'WALK'),
                                  size: 30,
                                ))),
                        WidgetSpan(
                            child: Column(
                          children: [
                            Text(
                              "${getPrettyDistance(itinerary['walkDistance'])}\n${getPrettyTime(itinerary['walkTime'])}",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black.withOpacity(0.5)),
                            )
                          ],
                        )),
                        WidgetSpan(
                            child: Visibility(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 30, right: 10),
                                  child:
                                      Icon(Icons.directions_transit, size: 30),
                                ),
                                visible: itinerary['transitTime'] > 0)),
                        WidgetSpan(
                            child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                  bottom: itinerary['transitTime'] > 0 ? 0 : 7),
                              child: Text(
                                "$transferText${(getPrettyTime(itinerary['transitTime']))}",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black.withOpacity(0.5)),
                              ),
                            )
                          ],
                        )),
                      ])))),
              // allign a star icon right
              Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                      padding: EdgeInsets.only(left: 10),
                      // star is hollow until clicked
                      child: IconButton(
                        icon: Icon(saved ? Icons.star : Icons.star_border,
                            size: 30),
                        onPressed: () {
                          toggleSaved();
                          debugPrint('star pressed!!!');
                        },
                      ))),
              // star is filled when clicked
            ],
          )),
    );
  }
}

String convertUnixToReadable(int unixTime) {
  var date = DateTime.fromMillisecondsSinceEpoch(unixTime);
  return DateFormat('hh:mm a').format(date);
}
