/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
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

import heresdk
import UIKit

class RoutingExample {

    private var viewController: UIViewController
    private var mapView: MapView
    private var mapMarkers = [MapMarker]()
    private var mapPolylineList = [MapPolyline]()
    private var routingEngine: RoutingEngine
    private var startGeoCoordinates: GeoCoordinates?
    private var destinationGeoCoordinates: GeoCoordinates?

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      distanceInMeters: 1000 * 10)

        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }
    }

    func addRoute() {
        startGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        destinationGeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        let carOptions = CarOptions()
        routingEngine.calculateRoute(with: [Waypoint(coordinates: startGeoCoordinates!),
                                            Waypoint(coordinates: destinationGeoCoordinates!)],
                                     carOptions: carOptions) { (routingError, routes) in

                                        if let error = routingError {
                                            self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                                            return
                                        }

                                        // When routingError is nil, routes is guaranteed to contain at least one route.
                                        let route = routes!.first
                                        self.showRouteDetails(route: route!)
                                        self.showRouteOnMap(route: route!)
                                        self.logRouteSectionDetails(route: route!)
                                        self.logRouteViolations(route: route!)
        }
    }

    // A route may contain several warnings, for example, when a certain route option could not be fulfilled.
    // An implementation may decide to reject a route if one or more violations are detected.
    private func logRouteViolations(route: Route) {
        let sections = route.sections
        for section in sections {
            for notice in section.sectionNotices {
                print("This route contains the following warning: \(notice.code)")
            }
        }
    }
    
    private func logRouteSectionDetails(route: Route) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        for (i, sections) in route.sections.enumerated() {
            print("Route Section : " + String(i));
            print("Route Section Departure Time : " + dateFormatter.string(from: sections.departureTime!));
            print("Route Section Arrival Time : " + dateFormatter.string(from: sections.arrivalTime!));
            print("Route Section length : " + "\(sections.lengthInMeters)" + " m");
            print("Route Section duration : " + "\(sections.duration)" + " s");
        }
    }

    private func showRouteDetails(route: Route) {
        let estimatedTravelTimeInSeconds = route.duration
        let lengthInMeters = route.lengthInMeters
        
        let routeDetails = "Travel Time: " + formatTime(sec: estimatedTravelTimeInSeconds)
                         + ", Length: " + formatLength(meters: lengthInMeters)

        showDialog(title: "Route Details", message: routeDetails)
    }

    private func formatTime(sec: Double) -> String {
        let hours: Double = sec / 3600
        let minutes: Double = (sec.truncatingRemainder(dividingBy: 3600)) / 60

        return "\(Int32(hours)):\(Int32(minutes))"
    }

    private func formatLength(meters: Int32) -> String {
        let kilometers: Int32 = meters / 1000
        let remainingMeters: Int32 = meters % 1000

        return "\(kilometers).\(remainingMeters) km"
    }

    private func showRouteOnMap(route: Route) {
        // Optionally, clear any previous route.
        clearMap()
        
        // Show route as polyline.
        let routeGeoPolyline = route.geometry
        let routeMapPolyline = MapPolyline(geometry: routeGeoPolyline,
                                           widthInPixels: 20,
                                           color: UIColor(red: 0,
                                                          green: 0.56,
                                                          blue: 0.54,
                                                          alpha: 0.63))
        mapView.mapScene.addMapPolyline(routeMapPolyline)
        mapPolylineList.append(routeMapPolyline)

        let startPoint = route.sections.first!.departurePlace.mapMatchedCoordinates
        let destination = route.sections.last!.arrivalPlace.mapMatchedCoordinates
        
        // Draw a circle to indicate starting point and destination.
        addCircleMapMarker(geoCoordinates: startPoint, imageName: "green_dot.png")
        addCircleMapMarker(geoCoordinates: destination, imageName: "green_dot.png")

        // Log maneuver instructions per route leg / sections.
        let sections = route.sections
        for section in sections {
            logManeuverInstructions(section: section)
        }
    }

    private func logManeuverInstructions(section: Section) {
        print("Log maneuver instructions per section:")
        let maneuverInstructions = section.maneuvers
        for maneuverInstruction in maneuverInstructions {
            let maneuverAction = maneuverInstruction.action
            let maneuverLocation = maneuverInstruction.coordinates
            let maneuverInfo = "\(maneuverInstruction.text)"
                + ", Action: \(maneuverAction)"
                + ", Location: \(maneuverLocation)"
            print(maneuverInfo)
        }
    }

    func addWaypoints() {
        guard
            let startGeoCoordinates = startGeoCoordinates,
            let destinationGeoCoordinates = destinationGeoCoordinates else {
                showDialog(title: "Error", message: "Please add a route first.")
                return
        }

        let waypoint1GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        let waypoint2GeoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        let waypoints = [Waypoint(coordinates: startGeoCoordinates),
                         Waypoint(coordinates: waypoint1GeoCoordinates),
                         Waypoint(coordinates: waypoint2GeoCoordinates),
                         Waypoint(coordinates: destinationGeoCoordinates)]

        let carOptions = CarOptions()
        routingEngine.calculateRoute(with: waypoints,
                                     carOptions: carOptions) { (routingError, routes) in

                                        if let error = routingError {
                                            self.showDialog(title: "Error while calculating a route:", message: "\(error)")
                                            return
                                        }

                                        let route = routes!.first
                                        self.showRouteDetails(route: route!)
                                        self.showRouteOnMap(route: route!)
                                        self.logRouteSectionDetails(route: route!)
                                        self.logRouteViolations(route: route!)

                                        // Draw a circle to indicate the location of the waypoints.
                                        self.addCircleMapMarker(geoCoordinates: waypoint1GeoCoordinates, imageName: "red_dot.png")
                                        self.addCircleMapMarker(geoCoordinates: waypoint2GeoCoordinates, imageName: "red_dot.png")
        }
    }

    func clearMap() {
        clearWaypointMapMarker()
        clearRoute()
    }

    private func clearWaypointMapMarker() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkers.removeAll()
    }

    private func clearRoute() {
        for mapPolyline in mapPolylineList {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylineList.removeAll()
    }

    private func createRandomGeoCoordinatesAroundMapCenter() -> GeoCoordinates {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)
        let centerPoint2D = Point2D(x: mapViewWidthInPixels / 2,
                                    y: mapViewHeightInPixels / 2)

        let centerGeoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: centerPoint2D)
        let lat = centerGeoCoordinates!.latitude
        let lon = centerGeoCoordinates!.longitude
        return GeoCoordinates(latitude: getRandom(min: lat - 0.02,
                                                  max: lat + 0.02),
                              longitude: getRandom(min: lon - 0.02,
                                                   max: lon + 0.02))
    }

    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min ... max)
    }

    private func addCircleMapMarker(geoCoordinates: GeoCoordinates, imageName: String) {
        guard
            let image = UIImage(named: imageName),
            let imageData = image.pngData() else {
                return
        }
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png))
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
