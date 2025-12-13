import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/destination_model.dart';
import '../services/database_service.dart';

class AddDestinationScreen extends StatefulWidget {
  final Destination? destination;
  final LatLng? selectedLocation;

  const AddDestinationScreen({
    Key? key,
    this.destination,
    this.selectedLocation,
  }) : super(key: key);

  @override
  State<AddDestinationScreen> createState() => _AddDestinationScreenState();
}

class _AddDestinationScreenState extends State<AddDestinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _imagePath;
  bool _isLoading = false;

  double? _latitude;
  double? _longitude;
  String? _locationName;

  @override
  void initState() {
    super.initState();

    if (widget.destination != null) {
      _nameController.text = widget.destination!.name;
      _descriptionController.text = widget.destination!.description;
      _selectedDate = widget.destination!.visitDate;
      _selectedTime = widget.destination!.visitTime != null
          ? TimeOfDay(
              hour: int.parse(widget.destination!.visitTime!.split(':')[0]),
              minute: int.parse(widget.destination!.visitTime!.split(':')[1]),
            )
          : null;
      _imagePath = widget.destination!.imagePath;
      _latitude = widget.destination!.latitude;
      _longitude = widget.destination!.longitude;
      _locationName = widget.destination!.location;
    }

    if (widget.selectedLocation != null) {
      _latitude = widget.selectedLocation!.latitude;
      _longitude = widget.selectedLocation!.longitude;
      _getLocationName();
    }
  }

  Future<void> _getLocationName() async {
    setState(() {
      _locationName =
          'Lokasi: ${_latitude?.toStringAsFixed(4)}°, ${_longitude?.toStringAsFixed(4)}°';
    });
  }

  Future<void> _showPhotoPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Pilih Foto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2196F3)),
              title: const Text('Ambil Foto (Kamera)'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF2196F3)),
              title: const Text('Upload dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  Future<void> _selectLocationFromMap() async {
    final LatLng? selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          currentLocation: _latitude != null && _longitude != null
              ? LatLng(_latitude!, _longitude!)
              : null,
        ),
      ),
    );

    if (selectedLocation != null) {
      setState(() {
        _latitude = selectedLocation.latitude;
        _longitude = selectedLocation.longitude;
      });
      _getLocationName();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  double _calculateCost() {
    if (_latitude == null || _longitude == null) return 0;

    const double userLat = -6.2088;
    const double userLong = 106.8456;

    double distance =
        _calculateDistance(userLat, userLong, _latitude!, _longitude!);

    double cost = distance * 5000;

    return cost;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  Future<void> _saveDestination() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitude == null || _longitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih lokasi dari peta terlebih dahulu'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    double cost = _calculateCost();

    // Ambil saldo dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    double currentBalance = prefs.getDouble('balance') ?? 40000;

    // Jika edit destinasi, tidak perlu cek saldo
    if (widget.destination == null && cost > currentBalance) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Saldo tidak cukup!\nBiaya: Rp ${cost.toStringAsFixed(0)}\nSaldo: Rp ${currentBalance.toStringAsFixed(0)}\n\nSilakan top up terlebih dahulu.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final destination = Destination(
      id: widget.destination?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationName ?? 'Unknown Location',
      latitude: _latitude!,
      longitude: _longitude!,
      imagePath: _imagePath,
      visitDate: _selectedDate,
      visitTime: _selectedTime != null
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null,
    );

    try {
      if (widget.destination == null) {
        // Tambah destinasi baru
        await DatabaseService.instance.createDestination(destination);

        // Kurangi saldo
        double newBalance = currentBalance - cost;
        await prefs.setDouble('balance', newBalance);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Destinasi berhasil ditambahkan!\n'
                'Biaya: Rp ${cost.toStringAsFixed(0)}\n'
                'Sisa Saldo: Rp ${newBalance.toStringAsFixed(0)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context, true); // Return true untuk refresh
        }
      } else {
        // Update destinasi
        await DatabaseService.instance.updateDestination(destination);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Destinasi berhasil diupdate'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double cost = _calculateCost();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
            widget.destination == null ? 'Tambah Destinasi' : 'Edit Destinasi'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoPicker(),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _nameController,
                label: 'Nama Destinasi',
                icon: Icons.place,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Nama harus diisi' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Deskripsi',
                icon: Icons.description,
                maxLines: 4,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Deskripsi harus diisi' : null,
              ),
              const SizedBox(height: 16),
              _buildLocationPicker(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDatePicker()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimePicker()),
                ],
              ),
              const SizedBox(height: 20),
              if (_latitude != null &&
                  _longitude != null &&
                  widget.destination == null)
                _buildCostInfo(cost),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _showPhotoPicker,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_imagePath!),
                  fit: BoxFit.cover,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Tambah Foto Destinasi',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kamera atau Upload dari Galeri',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return InkWell(
      onTap: _selectLocationFromMap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
          color: _latitude != null ? const Color(0xFFE8F5E9) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.map,
                  color: _latitude != null
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF2196F3),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _latitude != null
                        ? 'Lokasi Terpilih'
                        : 'Pilih Lokasi dari Peta',
                    style: TextStyle(
                      fontSize: 16,
                      color: _latitude != null
                          ? const Color(0xFF4CAF50)
                          : Colors.black87,
                      fontWeight: _latitude != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  _latitude != null
                      ? Icons.check_circle
                      : Icons.arrow_forward_ios,
                  color:
                      _latitude != null ? const Color(0xFF4CAF50) : Colors.grey,
                  size: _latitude != null ? 24 : 16,
                ),
              ],
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koordinat Otomatis:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_latitude!.toStringAsFixed(6)}°',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      'Long: ${_longitude!.toStringAsFixed(6)}°',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF2196F3)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate == null
                    ? 'Pilih Tanggal'
                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: _selectTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Color(0xFF2196F3)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedTime == null
                    ? 'Pilih Waktu'
                    : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostInfo(double cost) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFA726)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments, color: Color(0xFFFFA726)),
              const SizedBox(width: 12),
              const Text(
                'Biaya Perjalanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFA726),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${cost.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Akan dipotong dari saldo profil Anda',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveDestination,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.destination == null
                    ? 'Simpan Destinasi'
                    : 'Update Destinasi',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class MapLocationPicker extends StatefulWidget {
  final LatLng? currentLocation;

  const MapLocationPicker({Key? key, this.currentLocation}) : super(key: key);

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.currentLocation;
    if (_selectedLocation != null) {
      _addMarker(_selectedLocation!);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _addMarker(position);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            onTap: _onMapTapped,
            initialCameraPosition: CameraPosition(
              target: widget.currentLocation ?? const LatLng(-6.2088, 106.8456),
              zoom: 12,
            ),
            markers: _markers,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Pilih Lokasi Destinasi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedLocation != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Color(0xFF4CAF50), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Lokasi Terpilih:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}°',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Long: ${_selectedLocation!.longitude.toStringAsFixed(6)}°',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, _selectedLocation);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Lanjutkan Tambah Destinasi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
