import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:projet_fitnest/Geolocalisation/CategoryDropDown.dart';
import 'package:projet_fitnest/Geolocalisation/EventDetailsPage.dart';

class EventMapPage extends StatefulWidget {
  @override
  _EventMapPageState createState() => _EventMapPageState();
}

class _EventMapPageState extends State<EventMapPage> {
  List<Map<String, dynamic>> events = [];
  List<Marker> _markers = [];
  List<LatLng> _routeCoordinates = [];
  LatLng? _currentLocation;
  late final MapController _mapController;
  double _currentZoom = 10.0;
  String? selectedCategory;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    fetchEvents();
  }
  Future<void> locateMe() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LatLng currentLocation = LatLng(position.latitude, position.longitude);

      _mapController.move(currentLocation, 15.0); // Move map to current location
      setState(() {
        _currentLocation = currentLocation;
        print(_currentLocation);
        _currentZoom = 15.0;
        _createMarkers(); // Update markers to include the current location
      });
    } catch (e) {
      print('Error locating user: $e');
    }
  }
  Future<void> _getRoute(LatLng start, LatLng end) async {
    final response = await http.get(Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=5b3ce3597851110001cf6248465d6b0ae5b34c62881034d3a7aada1b&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}'
    ));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      List coordinates = data['features'][0]['geometry']['coordinates'];

      List<LatLng> routeCoordinates = coordinates.map<LatLng>((coord) {
        return LatLng(coord[1], coord[0]);
      }).toList();

      // Mise à jour des coordonnées de l'itinéraire
      setState(() {
        _routeCoordinates = routeCoordinates;
      });

      debugPrint('Itinéraire chargé avec succès : ${_routeCoordinates.length} points');
    } else {
      debugPrint('Erreur lors du chargement de l\'itinéraire : ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la récupération de l\'itinéraire.')),
      );
    }
  }
  void _showEventDialog(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(
          event: event,
          currentLocation: _currentLocation,
        ),
      ),
    );
  }
  void _createMarkers() {
    _markers = events.map((event) {
      return Marker(
        point: LatLng(event['location']['latitude'], event['location']['longitude']),
        width: 40.0 * (_currentZoom / 15),
        height: 40.0 * (_currentZoom / 15),
        builder: (ctx) => GestureDetector(
          onTap: () {
            _showEventDialog(event);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.purple.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.sports_soccer,
                color: Colors.white,
                size: 20.0 * (_currentZoom / 15),
              ),
            ),
          ),
        ),
      );
    }).toList();

    // Add a blue marker for the current location if available
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          point: _currentLocation!,
          width: 40.0 * (_currentZoom / 15),
          height: 40.0 * (_currentZoom / 15),
          builder: (ctx) => Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.person_pin_circle,
                color: Colors.white,
                size: 20.0 * (_currentZoom / 15),
              ),
            ),
          ),
        ),
      );
    }
  }
  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Erreur'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
  Future<void> fetchEvents() async {
    try {
      String url = 'http://localhost:8080/api/events';

      // Ajouter les paramètres de catégorie et de date
      if (selectedCategory != null) {
        url += '/category/$selectedCategory';
      } else if (startDate != null && endDate != null) {
        url = 'http://localhost:8080/api/events/between?startDate=${startDate!.toIso8601String()}&endDate=${endDate!.toIso8601String()}';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List fetchedEvents = json.decode(utf8.decode(response.bodyBytes));
        print(fetchedEvents);
        setState(() {
          events = fetchedEvents.map((event) => {
            'name': event['name'],
            'description': event['description'],
            'location_name': event['locationName'],
            'start_date': event['startDate'],
            'end_date': event['endDate'],
            'location': {
              'latitude': event['location']['latitude'],
              'longitude': event['location']['longitude']
            }
          }).toList();
          _createMarkers();
        });
      } else {
        throw Exception('Failed to load events');
      }
    } catch (e) {
      print('Error fetching events: $e');
      showErrorDialog('Échec de la récupération des événements. Veuillez réessayer.');
    }
  }

  void _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      fetchEvents(); // Récupérer les événements après la sélection de la date
    }
  }

  // Les autres fonctions (comme locateMe, _createMarkers, _getRoute, etc.) restent inchangées...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Carte des Événements'),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: locateMe,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation ?? LatLng(33.701847, -7.359415),
              zoom: _currentZoom,
              onPositionChanged: (MapPosition position, bool hasGesture) {
                setState(() {
                  _currentZoom = position.zoom ?? 10.0;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: _markers),
              if (_routeCoordinates.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeCoordinates,
                      color: Colors.blue,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: CategoryDropdown(
                    onCategorySelected: (String category) {
                      setState(() {
                        selectedCategory = category;
                        fetchEvents();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.date_range),
                  onPressed: _pickDateRange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
