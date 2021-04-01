/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/routing.dart';
import 'package:here_sdk/routing.dart' as here;
import 'package:here_sdk/search.dart';

// A callback to notify the hosting widget.
typedef ShowDialogFunction = void Function(String title, String message);

// This example shows how to calculate routes for electric vehicles that contain necessary charging stations
// (indicated with red charging icon). In addition, all existing charging stations are searched along the route
// (indicated with green charging icon). You can also visualize the reachable area from your starting point
// (isoline routing).
class EVRoutingExample {
  HereMapController _hereMapController;
  List<MapMarker> _mapMarkers = [];
  List<MapPolyline> _mapPolylines = [];
  List<MapPolygon> _mapPolygons = [];
  RoutingEngine _routingEngine;
  SearchEngine _searchEngine;
  GeoCoordinates _startGeoCoordinates;
  GeoCoordinates _destinationGeoCoordinates;
  ShowDialogFunction _showDialog;
  List<String> chargingStationsIDs = [];

  EVRoutingExample(Function showDialogCallback, HereMapController hereMapController) {
    _showDialog = showDialogCallback;
    _hereMapController = hereMapController;

    double distanceToEarthInMeters = 10000;
    _hereMapController.camera.lookAtPointWithDistance(GeoCoordinates(52.520798, 13.409408), distanceToEarthInMeters);

    try {
      _routingEngine = RoutingEngine();
    } on InstantiationException {
      throw ("Initialization of RoutingEngine failed.");
    }

    try {
      // Add search engine to search for places along a route.
      _searchEngine = new SearchEngine();
    } on InstantiationException {
      throw ("Initialization of SearchEngine failed.");
    }
  }

  // Calculates an EV car route based on random start / destination coordinates near viewport center.
  Future<void> addEVRoute() async {
    clearMap();
    chargingStationsIDs.clear();

    _startGeoCoordinates = _createRandomGeoCoordinatesInViewport();
    _destinationGeoCoordinates = _createRandomGeoCoordinatesInViewport();
    var startWaypoint = Waypoint(_startGeoCoordinates);
    var destinationWaypoint = Waypoint(_destinationGeoCoordinates);
    List<Waypoint> waypoints = [startWaypoint, destinationWaypoint];

    _routingEngine.calculateEVCarRoute(waypoints, _getEVCarOptions(),
        (RoutingError routingError, List<here.Route> routeList) {
      if (routingError == null) {
        here.Route route = routeList.first;
        _showRouteOnMap(route);
        _logRouteViolations(route);
        _logEVDetails(route);
        _searchAlongARoute(route);
      } else {
        var error = routingError.toString();
        _showDialog('Error', 'Error while calculating a route: $error');
      }
    });
  }

  EVCarOptions _getEVCarOptions() {
    EVCarOptions evCarOptions = EVCarOptions.withDefaults();

    // The below three options are the minimum you must specify or routing will result in an error.
    evCarOptions.consumptionModel.ascentConsumptionInWattHoursPerMeter = 9;
    evCarOptions.consumptionModel.descentRecoveryInWattHoursPerMeter = 4.3;
    evCarOptions.consumptionModel.freeFlowSpeedTable = {0: 0.239, 27: 0.239, 60: 0.196, 90: 0.238};

    // Ensure that the vehicle does not run out of energy along the way and charging stations are added as additional waypoints.
    evCarOptions.ensureReachability = true;

    // The below options are required when setting the ensureReachability option to true.
    evCarOptions.routeOptions.optimizationMode = OptimizationMode.fastest;
    evCarOptions.routeOptions.alternatives = 0;
    evCarOptions.batterySpecifications.connectorTypes = [
      ChargingConnectorType.tesla,
      ChargingConnectorType.iec62196Type1Combo,
      ChargingConnectorType.iec62196Type2Combo
    ];
    evCarOptions.batterySpecifications.totalCapacityInKilowattHours = 80.0;
    evCarOptions.batterySpecifications.initialChargeInKilowattHours = 10.0;
    evCarOptions.batterySpecifications.targetChargeInKilowattHours = 72.0;
    evCarOptions.batterySpecifications.chargingCurve = {0.0: 239.0, 64.0: 111.0, 72.0: 1.0};

    // Note: More EV options are available, the above shows only the minimum viable options.
    return evCarOptions;
  }

  void _logEVDetails(here.Route route) {
    // Find inserted charging stations that are required for this route.
    // Note that this example assumes only one start waypoint and one destination waypoint.
    // By default, each route has one section.
    int additionalSectionCount = route.sections.length - 1;
    if (additionalSectionCount > 0) {
      // Each additional waypoint splits the route into two sections.
      print("EVDetails: Number of required stops at charging stations: $additionalSectionCount");
    } else {
      print(
          "EVDetails: Based on the provided options, the destination can be reached without a stop at a charging station.");
    }

    int sectionIndex = 0;
    List<Section> sections = route.sections;
    for (Section section in sections) {
      EVDetails evDetails = section.evDetails;
      print("EVDetails: Estimated net energy consumption in kWh for this section: " +
          evDetails.consumptionInKilowattHour.toString());
      for (PostAction postAction in section.postActions) {
        switch (postAction.action) {
          case PostActionType.chargingSetup:
            print("EVDetails: At the end of this section you need to setup charging for " +
                postAction.durationInSeconds.toString() +
                " s.");
            break;
          case PostActionType.charging:
            print("EVDetails: At the end of this section you need to charge for " +
                postAction.durationInSeconds.toString() +
                " s.");
            break;
          case PostActionType.wait:
            print("EVDetails: At the end of this section you need to wait for " +
                postAction.durationInSeconds.toString() +
                " s.");
            break;
          default:
            throw ("Unknown post action type.");
        }
      }

      print("EVDetails: Section " +
          sectionIndex.toString() +
          ": Estimated departure battery charge in kWh: " +
          section.departure.chargeInKilowattHours.toString());
      print("EVDetails: Section " +
          sectionIndex.toString() +
          ": Estimated arrival battery charge in kWh: " +
          section.arrival.chargeInKilowattHours.toString());

      // Only charging stations that are needed to reach the destination are listed below.
      ChargingStation depStation = section.departure.chargingStation;
      if (depStation != null && depStation.id != null && !chargingStationsIDs.contains(depStation.id)) {
        print("EVDetails: Section " + sectionIndex.toString() + ", name of charging station: " + depStation.name);
        chargingStationsIDs.add(depStation.id);
        _addCircleMapMarker(section.departure.mapMatchedCoordinates, "assets/required_charging.png");
      }

      ChargingStation arrStation = section.departure.chargingStation;
      if (arrStation != null && arrStation.id != null && !chargingStationsIDs.contains(arrStation.id)) {
        print("EVDetails: Section " + sectionIndex.toString() + ", name of charging station: " + arrStation.name);
        chargingStationsIDs.add(arrStation.id);
        _addCircleMapMarker(section.arrival.mapMatchedCoordinates, "assets/required_charging.png");
      }

      sectionIndex += 1;
    }
  }

  // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
  // An implementation may decide to reject a route if one or more violations are detected.
  void _logRouteViolations(here.Route route) {
    for (var section in route.sections) {
      for (var notice in section.notices) {
        print("This route contains the following warning: " + notice.code.toString());
      }
    }
  }

  // Perform a search for charging stations along the found route.
  void _searchAlongARoute(here.Route route) {
    // We specify here that we only want to include results
    // within a max distance of xx meters from any point of the route.
    int radiusInMeters = 200;
    GeoCorridor routeCorridor = GeoCorridor.withRadius(route.polyline, radiusInMeters);
    TextQuery textQuery = TextQuery.withCorridorAreaAndAreaCenter(
        "charging station", routeCorridor, _hereMapController.camera.state.targetCoordinates);

    int maxItems = 30;
    SearchOptions searchOptions = new SearchOptions(LanguageCode.enUs, maxItems);

    _searchEngine.searchByText(textQuery, searchOptions, (SearchError searchError, List<Place> items) {
      if (searchError != null) {
        if (searchError == SearchError.polylineTooLong) {
          // Increasing corridor radius will result in less precise results with the benefit of a less
          // complex route shape.
          print("Search: Route too long or route corridor radius too small.");
        } else {
          print("Search: No charging stations found along the route. Error: $searchError");
        }
        return;
      }

      // If error is nil, it is guaranteed that the items will not be nil.
      var listLength = items.length;
      print("Search: Search along route found $listLength charging stations:");
      for (Place place in items) {
        if (chargingStationsIDs.contains(place.id)) {
          print(
              "Search: Skipping: This charging station was already required to reach the destination (see red charging icon).");
        } else {
          // Only suggestions may not contain geoCoordinates, so it's safe to unwrap this search result's coordinates.
          _addCircleMapMarker(place.geoCoordinates, "assets/charging.png");
          print("Search: " + place.address.addressText);
        }
      }
    });
  }

  // Shows the reachable area for this electric vehicle from the current start coordinates and EV car options when the goal is
  // to consume 400 Wh or less (see options below).
  Future<void> showReachableArea() async {
    if (_startGeoCoordinates == null) {
      _showDialog("Error", "Please add at least one route first.");
      return;
    }

    // This finds the area that an electric vehicle can reach by consuming 400 Wh or less,
    // while trying to take the fastest possible route into any possible straight direction from start.
    // Note: We have specified evCarOptions.routeOptions.optimizationMode = OptimizationMode.FASTEST for EV car options above.
    List<int> rangeValues = [400];

    // With null we choose the default option for the resulting polygon shape.
    int maxPoints = null;
    IsolineOptionsCalculation calculationOptions = IsolineOptionsCalculation(
        IsolineRangeType.consumptionInWattHours, rangeValues, IsolineCalculationMode.balanced, maxPoints);
    IsolineOptions isolineOptions = IsolineOptions.withEVCarOptions(calculationOptions, _getEVCarOptions());

    _routingEngine.calculateIsoline(Waypoint(_startGeoCoordinates), isolineOptions,
        (RoutingError routingError, List<Isoline> list) {
      if (routingError != null) {
        _showDialog("Error while calculating reachable area:", routingError.toString());
        return;
      }

      // When routingError is nil, the isolines list is guaranteed to contain at least one isoline.
      // The number of isolines matches the number of requested range values. Here we have used one range value,
      // so only one isoline object is expected.
      Isoline isoline = list.first;

      // If there is more than one polygon, the other polygons indicate separate areas, for example, islands, that
      // can only be reached by a ferry.
      for (GeoPolygon geoPolygon in isoline.polygons) {
        // Show polygon on map.
        Color fillColor = Color.fromARGB(128, 0, 143, 138);
        MapPolygon mapPolygon = new MapPolygon(geoPolygon, fillColor);
        _hereMapController.mapScene..addMapPolygon(mapPolygon);
        _mapPolygons.add(mapPolygon);
      }
    });
  }

  void clearMap() {
    _clearWaypointMapMarker();
    _clearRoute();
    _clearIsolines();
  }

  void _clearWaypointMapMarker() {
    for (MapMarker mapMarker in _mapMarkers) {
      _hereMapController.mapScene.removeMapMarker(mapMarker);
    }
    _mapMarkers.clear();
  }

  void _clearRoute() {
    for (var mapPolyline in _mapPolylines) {
      _hereMapController.mapScene.removeMapPolyline(mapPolyline);
    }
    _mapPolylines.clear();
  }

  void _clearIsolines() {
    for (MapPolygon mapPolygon in _mapPolygons) {
      _hereMapController.mapScene.removeMapPolygon(mapPolygon);
    }
    _mapPolygons.clear();
  }

  _showRouteOnMap(here.Route route) {
    // Show route as polyline.
    GeoPolyline routeGeoPolyline = GeoPolyline(route.polyline);

    double widthInPixels = 20;
    MapPolyline routeMapPolyline = MapPolyline(routeGeoPolyline, widthInPixels, Color.fromARGB(160, 0, 144, 138));

    _hereMapController.mapScene.addMapPolyline(routeMapPolyline);
    _mapPolylines.add(routeMapPolyline);

    // Draw a circle to indicate starting point and destination.
    _addCircleMapMarker(_startGeoCoordinates, "assets/green_dot.png");
    _addCircleMapMarker(_destinationGeoCoordinates, "assets/red_dot.png");
  }

  void _addCircleMapMarker(GeoCoordinates geoCoordinates, String imageName) {
    // For this app, we only add images of size 60x60 pixels.
    int imageWidth = 60;
    int imageHeight = 60;
    // Note that you can optionally optimize by reusing the mapImage instance for other MapMarker instance.
    MapImage mapImage = MapImage.withFilePathAndWidthAndHeight(imageName, imageWidth, imageHeight);
    MapMarker mapMarker = MapMarker(geoCoordinates, mapImage);
    _hereMapController.mapScene.addMapMarker(mapMarker);
    _mapMarkers.add(mapMarker);
  }

  GeoCoordinates _createRandomGeoCoordinatesInViewport() {
    GeoBox geoBox = _hereMapController.camera.boundingBox;
    if (geoBox == null) {
      // Happens only when map is not fully covering the viewport.
      return GeoCoordinates(52.530932, 13.384915);
    }

    GeoCoordinates northEast = geoBox.northEastCorner;
    GeoCoordinates southWest = geoBox.southWestCorner;

    double minLat = southWest.latitude;
    double maxLat = northEast.latitude;
    double lat = _getRandom(minLat, maxLat);

    double minLon = southWest.longitude;
    double maxLon = northEast.longitude;
    double lon = _getRandom(minLon, maxLon);

    return new GeoCoordinates(lat, lon);
  }

  double _getRandom(double min, double max) {
    return min + Random().nextDouble() * (max - min);
  }
}
