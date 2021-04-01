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

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

import 'MapMarkerExample.dart';

void main() {
  SdkContext.init(IsolateOrigin.main);
  // Making sure that BuildContext has MaterialLocalizations widget in the widget tree,
  // which is part of MaterialApp.
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  // Use _context only within the scope of this widget.
  BuildContext _context;
  MapMarkerExample _mapMarkerExample;

  @override
  Widget build(BuildContext context) {
    _context = context;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('HERE SDK - Map Marker Example'),
        ),
        body: Stack(
          children: [
            HereMap(onMapCreated: _onMapCreated),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    button('Anchored (2D)', _anchoredMapMarkersButtonClicked),
                    button('Centered (2D)', _centeredMapMarkersButtonClicked),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    button('Flat', _flatMapMarkersButtonClicked),
                    button('3D OBJ', _mapMarkers3DButtonClicked),
                    button('Clear', _clearButtonClicked),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(HereMapController hereMapController) {
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay, (MapError error) {
      if (error == null) {
        _mapMarkerExample = MapMarkerExample(_showDialog, hereMapController);
      } else {
        print("Map scene not loaded. MapError: " + error.toString());
      }
    });
  }

  void _anchoredMapMarkersButtonClicked() {
    _mapMarkerExample.showAnchoredMapMarkers();
  }

  void _centeredMapMarkersButtonClicked() {
    _mapMarkerExample.showCenteredMapMarkers();
  }

  void _flatMapMarkersButtonClicked() {
    _mapMarkerExample.showFlatMapMarkers();
  }

  void _mapMarkers3DButtonClicked() {
    _mapMarkerExample.showMapMarkers3D();
  }

  void _clearButtonClicked() {
    _mapMarkerExample.clearMap();
  }

  // A helper method to add a button on top of the HERE map.
  Align button(String buttonLabel, Function callbackFunction) {
    return Align(
      alignment: Alignment.topCenter,
      child: RaisedButton(
        color: Colors.lightBlueAccent,
        textColor: Colors.white,
        onPressed: () => callbackFunction(),
        child: Text(buttonLabel, style: TextStyle(fontSize: 20)),
      ),
    );
  }

  // A helper method to add a button on top of the HERE map.
  Future<void> _showDialog(String title, String message) async {
    return showDialog<void>(
      context: _context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
