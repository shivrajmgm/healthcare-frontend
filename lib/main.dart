import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const CareSyncApp());
}

class CareSyncApp extends StatelessWidget {
  const CareSyncApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareSync HMS',
      theme: ThemeData(
        // Switch to Dark Brightness to automatically make text and fields light
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8), // Brighter teal/cyan for dark mode
          brightness: Brightness.dark, 
        ),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: const RoleSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Wrapper for the background image
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/blak-abstract-unsplash.jpg'), // Ensure this matches your image name
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent, 
        appBar: AppBar(
          title: const Text('CareSync HMS Portal', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.black.withOpacity(0.5),
          elevation: 0,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildRoleCard(context, 'Patient Portal', Icons.personal_injury, 'Book appointments', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentBookingScreen()))),
                  const SizedBox(width: 32),
                  _buildRoleCard(context, 'Doctor Portal', Icons.medical_information, 'Manage queues & Rx', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DoctorLoginScreen()))),
                  const SizedBox(width: 32),
                  // New Admin Card added here
                  _buildRoleCard(context, 'Admin Portal', Icons.insights, 'Hospital analytics', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, String title, IconData icon, String description, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Card(
          // Dark glassmorphism effect
          color: Colors.black.withOpacity(0.6), 
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1), // Subtle outline
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 24),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({Key? key}) : super(key: key);
  @override
  _AppointmentBookingScreenState createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController symptomsController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  
  String assignedDoctor = "";
  bool isProcessing = false;
  bool isTriaging = false;

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (pickedTime != null) {
        final DateTime finalDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        setState(() => dateController.text = "${finalDateTime.year}-${finalDateTime.month.toString().padLeft(2, '0')}-${finalDateTime.day.toString().padLeft(2, '0')} ${finalDateTime.hour.toString().padLeft(2, '0')}:${finalDateTime.minute.toString().padLeft(2, '0')}");
      }
    }
  }

  Future<void> autoTriageSymptoms() async {
    if (symptomsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe your symptoms first.')));
      return;
    }
    setState(() => isTriaging = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/triage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"symptoms": symptomsController.text}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          assignedDoctor = data['assigned_doctor'];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned to ${data['specialty']}'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Triage engine offline.')));
    } finally {
      setState(() => isTriaging = false);
    }
  }

  Future<void> finalizeBooking() async {
    if (nameController.text.isEmpty || emailController.text.isEmpty || dateController.text.isEmpty || assignedDoctor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields and analyze symptoms.')));
      return;
    }
    
    setState(() => isProcessing = true);
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/appointments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "patient_name": nameController.text, "patient_phone": phoneController.text,
          "patient_email": emailController.text, "doctor_name": assignedDoctor,
          "appointment_date": dateController.text,
        }),
      );

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
            content: const Text("Booking Confirmed!\n\nPlease check your email for the UPI payment QR code.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
          ),
        );
        nameController.clear(); phoneController.clear(); emailController.clear(); symptomsController.clear(); dateController.clear();
        setState(() => assignedDoctor = "");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Book Appointment'), backgroundColor: Colors.black.withOpacity(0.5), elevation: 0),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                color: Colors.black.withOpacity(0.75), 
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Patient Registration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      
                      // Smart Triage Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI Symptom Triage', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(controller: symptomsController, maxLines: 2, decoration: const InputDecoration(labelText: 'Describe your symptoms (e.g. severe headache)', border: OutlineInputBorder())),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: isTriaging ? null : autoTriageSymptoms,
                                  icon: isTriaging ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.psychology),
                                  label: const Text('Analyze'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: Text(assignedDoctor.isEmpty ? 'No doctor assigned' : 'Assigned: $assignedDoctor', style: TextStyle(color: assignedDoctor.isEmpty ? Colors.grey : Colors.greenAccent, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      TextField(controller: dateController, readOnly: true, onTap: () => _selectDateTime(context), decoration: const InputDecoration(labelText: 'Appointment Date & Time', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder())),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: isProcessing ? null : finalizeBooking,
                        icon: isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
                        label: Text(isProcessing ? 'Processing...' : 'Confirm Booking', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.black, 
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({Key? key}) : super(key: key);
  @override
  _DoctorLoginScreenState createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final TextEditingController loginController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Doctor Portal Login'), backgroundColor: Colors.black.withOpacity(0.5), elevation: 0),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              color: Colors.black.withOpacity(0.75),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 80, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 24),
                    TextField(controller: loginController, decoration: const InputDecoration(labelText: 'Enter Doctor Name', border: OutlineInputBorder())),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        if (loginController.text.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorDashboardScreen(doctorName: loginController.text)));
                        }
                      },
                      child: const Text('Access Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorDashboardScreen extends StatefulWidget {
  final String doctorName;
  const DoctorDashboardScreen({Key? key, required this.doctorName}) : super(key: key);
  @override
  _DoctorDashboardScreenState createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  List appointments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    final url = Uri.parse('http://localhost:8000/appointments/doctor/${widget.doctorName}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() { appointments = jsonDecode(response.body); isLoading = false; });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> issuePrescription(int id, String text) async {
    final url = Uri.parse('http://localhost:8000/appointments/$id/prescription');
    await http.put(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({"prescription": text}));
    fetchAppointments();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-Prescription attached to record.')));
  }

  void openPrescriptionDialog(int appointmentId, String patientName) {
    TextEditingController rxController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Prescribe for $patientName', style: const TextStyle(color: Colors.white)),
        content: TextField(controller: rxController, maxLines: 4, decoration: const InputDecoration(hintText: 'Enter diagnosis and medications...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { issuePrescription(appointmentId, rxController.text); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
            child: const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('${widget.doctorName} - Dashboard'),
          backgroundColor: Colors.black.withOpacity(0.5),
          elevation: 0,
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() => isLoading=true); fetchAppointments(); })],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : appointments.isEmpty
                ? Center(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)), child: const Text("No upcoming patients in queue.", style: TextStyle(fontSize: 18, color: Colors.white))))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final apt = appointments[index];
                      final hasRx = apt['prescription'] != null && apt['prescription'] != "";
                      return Card(
                        color: Colors.black.withOpacity(0.7),
                        shape: RoundedRectangleBorder(side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1), borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary, child: Text(apt['patient_name'][0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                          title: Text(apt['patient_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          subtitle: Text("Time: ${apt['appointment_date']}\nContact: ${apt['patient_phone']}", style: TextStyle(color: Colors.grey[400])),
                          isThreeLine: true,
                          trailing: ElevatedButton.icon(
                            onPressed: () => openPrescriptionDialog(apt['id'], apt['patient_name']),
                            icon: Icon(hasRx ? Icons.check_circle : Icons.edit_note, color: Colors.black),
                            label: Text(hasRx ? 'Update Rx' : 'Write Rx'),
                            style: ElevatedButton.styleFrom(backgroundColor: hasRx ? Colors.greenAccent : Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> stats = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/admin/stats'));
      if (response.statusCode == 200) {
        setState(() { stats = jsonDecode(response.body); isLoading = false; });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Hospital Management Analytics'), backgroundColor: Colors.black.withOpacity(0.5), elevation: 0),
        body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Patients', stats['total_appointments'].toString(), Icons.people)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Total Revenue', '₹${stats['total_revenue']}', Icons.currency_rupee)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Card(
                      color: Colors.black.withOpacity(0.7),
                      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1), borderRadius: BorderRadius.circular(16)),
                      child: ListView.builder(
                        itemCount: (stats['doctor_load'] as List).length,
                        itemBuilder: (context, index) {
                          final doc = stats['doctor_load'][index];
                          return ListTile(
                            leading: const Icon(Icons.person, color: Colors.cyanAccent),
                            title: Text(doc['doctor'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: Text('${doc['count']} Patients', style: const TextStyle(color: Colors.greenAccent, fontSize: 16)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.black.withOpacity(0.75),
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1), borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.cyanAccent),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}