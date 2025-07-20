import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cropsController = TextEditingController();
  String _location = 'Detecting location...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingData();
    _requestLocationPermission(); // Request permissions on init
  }

  Future<void> _checkExistingData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name');
    final location = prefs.getString('location');
    final crops = prefs.getString('crops');

    if (name != null && location != null && crops != null) {
      // Data exists, navigate to home page
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // Data does not exist, get location and show form
      await _getLocation();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied.');
        // Handle denial - maybe show a message to the user
      } else if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied. We cannot request permissions.');
        // Handle permanent denial - maybe direct user to app settings
      } else {
        print('Location permissions granted.');
        // Permissions granted, you can now attempt to get location
      }
    } else if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied. We cannot request permissions.');
    }
  }

 Future<void> _getLocation() async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    print(placemarks);

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      setState(() {
        _location = place.locality ?? 'Unknown City';
      });
    } else {
      setState(() {
        _location = 'City not found';
      });
    }
  } catch (e) {
    setState(() {
      _location = 'Could not get location: $e';
    });
  }
}

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameController.text);
      await prefs.setString('location', _location);
      await prefs.setString('crops', _cropsController.text);

      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cropsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              ListTile(
                title: const Text('Location'),
                subtitle: Text(_location),
                trailing: _location == 'Detecting location...'
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _getLocation,
                      ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _cropsController,
                decoration: const InputDecoration(labelText: 'Crops Grown'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the crops you grow';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _saveData,
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}