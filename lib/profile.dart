import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:convert';

void main() {
  runApp(Profile());
}

class Profile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profile UI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = '';
  String qoute =
      '"And, when you want something, all the universe conspires in helping you to achieve it."';
  String quoteAuthor = '- Paulo Coelho';
  String bio = '';
  String ambition = '';
  String? imagePath;
  Map<String, List<Map<String, int>>> _pomodoroData = {};


  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }


  Future<void> _initializePreferences() async {
  
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedData = prefs.getString('pomodoroData');

    if (storedData != null) {
      // Decode the stored JSON string into a map
      _pomodoroData = Map<String, List<Map<String, int>>>.from(
          jsonDecode(storedData).map((key, value) =>
              MapEntry(key, List<Map<String, int>>.from(value))));
    }

  }



  _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? '';
      qoute = prefs.getString('quote') ??
          '"And, when you want something, all the universe conspires in helping you to achieve it."';
      quoteAuthor = prefs.getString('quoteAuthor') ?? '- Paulo Coelho';
      bio = prefs.getString('bio') ?? '';
      ambition = prefs.getString('ambition') ?? '';
      imagePath = prefs.getString('imagePath');
    });
  }

  _saveProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('name', name);
    prefs.setString('quote', qoute);
    prefs.setString('quoteAuthor', quoteAuthor);
    prefs.setString('bio', bio);
    prefs.setString('ambition', ambition);
    if (imagePath != null) {
      prefs.setString('imagePath', imagePath!);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final directory = await getApplicationDocumentsDirectory();
      final name = path.basename(image.path);
      final savedImage = await File(image.path).copy('${directory.path}/$name');

      setState(() {
        imagePath = savedImage.path;
      });
      _saveProfileData();
    }
  }


   Map<String, double> getLast7DaysPomodoroHours() {
    DateTime now = DateTime.now();
    Map<String, double> hoursPerDay = {};

    for (int i = 0; i < 7; i++) {
      // Get the date for the current iteration (today, yesterday, etc.)
      DateTime day = now.subtract(Duration(days: i));
      String dayKey = "${day.day}/${day.month}"; // Format as day/month

      // Check if there are Pomodoro sessions for this day
      if (_pomodoroData.containsKey(dayKey)) {
        List<Map<String, int>> daySessions = _pomodoroData[dayKey]!;

        int totalMilliseconds = 0;

        // Sum the time spent in each Pomodoro session for this day
        for (var session in daySessions) {
          int? startTime = session["startTime"];
          int? stopTime = session["stopTime"];

          // Only count completed sessions (where stopTime is not null)
          if (startTime != null && stopTime != null) {
            totalMilliseconds += (stopTime - startTime);
          }
        }

        // Convert total milliseconds to hours and store in the map
        double totalHours = totalMilliseconds / (1000 * 60 * 60);
        hoursPerDay[dayKey] = totalHours;
      } else {
        // If no sessions, store 0 hours for that day
        hoursPerDay[dayKey] = 0;
      }
    }

    return hoursPerDay;
  }


  Map<String, dynamic> getPomodoroSummaryForLast7Days() {
  // Get the Pomodoro data for the last 7 days
  Map<String, double> pomodoroData = getLast7DaysPomodoroHours();

  // Calculate the total hours and streak
  double totalHours = 0;
  int totalMinutes = 0;
  int streak = 0;

  pomodoroData.forEach((date, hours) {
    totalHours += hours;
    totalMinutes += (hours * 60).toInt();  // Convert hours to minutes
    if (hours > 0) {
      streak++;  // Increment streak if hours > 0
    }
  });

  // Return a map with the results
  return {
    'totalHours': totalHours,
    'totalMinutes': totalMinutes,
    'streak': streak,
  };
}

int getGrandTotalStreak(Map<String, double> allPomodoroData) {
  int currentStreak = 0;
  int grandTotalStreak = 0;

  // Sort the dates in chronological order
  List<String> sortedDates = allPomodoroData.keys.toList()
    ..sort((a, b) {
      List<int> aParts = a.split('/').map(int.parse).toList();
      List<int> bParts = b.split('/').map(int.parse).toList();
      
      DateTime aDate = DateTime(2024, aParts[1], aParts[0]);  // Adjust year as needed
      DateTime bDate = DateTime(2024, bParts[1], bParts[0]);
      
      return aDate.compareTo(bDate);  // Sort in ascending order
    });

  // Iterate through the sorted dates and calculate streak
  for (String date in sortedDates) {
    double hours = allPomodoroData[date] ?? 0;

    if (hours > 0) {
      currentStreak++;  // Increment current streak if hours > 0
    } else {
      // Update the grand total streak if the current streak is longer
      if (currentStreak > grandTotalStreak) {
        grandTotalStreak = currentStreak;
      }
      currentStreak = 0;  // Reset the current streak
    }
  }

  // After the loop, check if the last streak is the longest
  if (currentStreak > grandTotalStreak) {
    grandTotalStreak = currentStreak;
  }

  return grandTotalStreak;
}


int getGrandTotalPomodoros(Map<String, double> allPomodoroData) {
  double totalHours = 0;

  // Sum up all the Pomodoro hours
  allPomodoroData.forEach((date, hours) {
    totalHours += hours;
  });

  // Assuming each Pomodoro session is 25 minutes or 0.4167 hours
  const double pomodoroDurationInHours = 25 / 60;

  // Calculate the total number of Pomodoros
  int totalPomodoros = (totalHours / pomodoroDurationInHours).floor();

  return totalPomodoros;
}




  void _editProfile() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: imagePath != null
                        ? FileImage(File(imagePath!))
                        : AssetImage('assets/placeholder.jpg') as ImageProvider,
                    child: Icon(Icons.camera_alt, color: Colors.white54),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(labelText: 'Name'),
                  onChanged: (value) => name = value,
                  controller: TextEditingController(text: name),
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Bio'),
                  onChanged: (value) => bio = value,
                  controller: TextEditingController(text: bio),
                ),
                TextField(
                  decoration:
                      InputDecoration(labelText: 'Your Ambition (one word)'),
                  onChanged: (value) => ambition = value,
                  controller: TextEditingController(text: ambition),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                _saveProfileData();
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: imagePath != null
                              ? FileImage(File(imagePath!))
                              : AssetImage('')
                                  as ImageProvider,
                        ),

                        SizedBox(height: 10),
                       
                            Text(
                                name,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                           
                        bio.isNotEmpty
                            ? Text(
                                bio,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              )
                            : Column(
                              children: [
                                IconButton(
                                icon: Icon(Icons.add, color: Colors.black),
                                onPressed: _editProfile,
                                ),
                                const Text(
                                'Add Profile',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                                ),
                              ],
                              ),
                        SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            qoute,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        ),
                        Text(
                          quoteAuthor,
                          style: TextStyle(color: Colors.black, fontSize: 14),
                        ),
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                          children: [
                            const Text(
                            'Activities',
                            style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            ),
                            SizedBox(height: 10),
                            Text(
                            getPomodoroSummaryForLast7Days()['totalHours'].toString(),
                            style: const TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255),
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                            ),
                            const Text(
                            'hrs, Last 7 days',
                            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 16),
                            ),
                            SizedBox(height: 20),
                            Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn(getGrandTotalStreak(getLast7DaysPomodoroHours()).toString(), 'Total Streak'),
                                _buildStatColumn(getGrandTotalPomodoros(getLast7DaysPomodoroHours()).toString(), 'Total Pomorodo'),
                              ],
                              ),
                              SizedBox(width: 20), // Changed from height to width
                             
                            ],
                            ),
                          ],
                          ),
                        ),
                        
                        if (ambition.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                          child: Text.rich(
                            TextSpan(
                              text: "You'r one step closer to your dream of becoming a ",
                              style: TextStyle(color: Colors.black, fontSize: 14),
                              children: <TextSpan>[
                                TextSpan(
                                  text: ambition,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // ... [rest of the UI remains the same]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 20,
            right: 10,
            child: IconButton(
              icon: Icon(Icons.edit, color: Colors.black),
              onPressed: _editProfile,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            value,
            style: TextStyle(
              color: const Color.fromARGB(255, 255, 255, 255),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(color: const Color.fromARGB(255, 255, 255, 255), fontSize: 14),
        ),
      ],
    );
  }
}
