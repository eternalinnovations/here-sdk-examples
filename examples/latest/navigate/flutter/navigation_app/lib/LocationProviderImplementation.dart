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

import 'package:here_sdk/core.dart' as HERE;
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/navigation.dart' as HERE;
import 'package:here_sdk/routing.dart' as HERE;

// This class provides simulated location events (requires a route).
// Alternatively, check the positioning example code in the developer's guide
// to see how to get real location events from a device.
class LocationProviderImplementation {
  HERE.LocationSimulator _locationSimulator;

  // Provides location updates based on the given route.
  void enableRoutePlayback(HERE.Route route, HERE.LocationListener locationListener) {
    _locationSimulator?.stop();

    _locationSimulator = _createLocationSimulator(route, locationListener);
    _locationSimulator.start();
  }

  void stop() {
    _locationSimulator?.stop();
  }

  // Provides fake GPS signals based on the route geometry.
  HERE.LocationSimulator _createLocationSimulator(HERE.Route route, HERE.LocationListener locationListener) {
    final double speedFactor = 2;
    final notificationIntervalInMilliseconds = 500;
    HERE.LocationSimulatorOptions locationSimulatorOptions = HERE.LocationSimulatorOptions(
      speedFactor,
      notificationIntervalInMilliseconds,
    );

    HERE.LocationSimulator locationSimulator;

    try {
      locationSimulator = HERE.LocationSimulator.withRoute(route, locationSimulatorOptions);
    } on InstantiationException {
      throw Exception("Initialization of LocationSimulator failed.");
    }

    locationSimulator.listener = locationListener;

    return locationSimulator;
  }
}
