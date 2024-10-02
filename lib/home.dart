import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:localstorage/localstorage.dart';

void main() {
  runApp(Home());
}

class Home extends StatelessWidget {
  final LocalStorage storage = LocalStorage('localstorage_app');
  Map<String, List<Map<String, int>>> _pomodoroData = {};
  
 
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

  late final pomorodo;

  @override
  void initState() {
    pomorodo = storage.getItem('pomodoroData');
  }

  int getPomodorosForToday() {
    print("pomorodData: $_pomodoroData");

     print("pomorodData form local: ${storage.getItem('pomodoroData')}");

    DateTime now = DateTime.now();
    String todayKey = "${now.year}/${now.month}/${now.day}";

    // Check if today's key exists in the data
    var pomodoroData = storage.getItem('pomodoroData');
    if (pomodoroData != null && pomodoroData.containsKey(todayKey)) {
      // Return the number of Pomodoro sessions for today
      return storage.getItem('pomodoroData')[todayKey]?.length ?? 0;
    }

    // If no sessions exist for today, return 0
    return 0;
  }

 double getTotalPomodoroHoursForToday() {
  DateTime now = DateTime.now();
  String todayKey = "${now.year}/${now.month}/${now.day}";

  // Check if there are Pomodoro sessions for today
  var pomodoroData = storage.getItem('pomodoroData');
  if (pomodoroData != null && pomodoroData?.containsKey(todayKey)) {
    // Retrieve the dynamic list from local storage
    List<dynamic> todaySessionsDynamic = storage.getItem('pomodoroData')[todayKey];

    int totalMilliseconds = 0;

    // Iterate through the dynamic list and ensure proper casting
    for (var session in todaySessionsDynamic) {
      // Cast session to Map<String, dynamic> first
      Map<String, dynamic> sessionMap = session as Map<String, dynamic>;

      // Safely extract startTime and stopTime as int? and ensure they are valid integers
      int? startTime = sessionMap["startTime"] is int ? sessionMap["startTime"] as int? : null;
      int? stopTime = sessionMap["stopTime"] is int ? sessionMap["stopTime"] as int? : null;

      // Only count completed sessions (where stopTime is not null and not -1)
      if (startTime != null && stopTime != null && stopTime != -1) {
        totalMilliseconds += (stopTime - startTime);
      }
    }

    // Convert the total milliseconds to hours
    double totalHours = totalMilliseconds / (1000 * 60 * 60);
  
    return totalHours;

  }

  // Return 0 if there are no sessions for today
  return 0;
}


  Map<String, double> getLast7DaysPomodoroHours() {
  DateTime now = DateTime.now();
  Map<String, double> hoursPerDay = {};

  for (int i = 0; i < 7; i++) {
    // Get the date for the current iteration (today, yesterday, etc.)
    DateTime day = now.subtract(Duration(days: i));
    String dayKey = "${day.day}/${day.month}";  // Format as day/month

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


 
//  Map<String, dynamic> getPomodoroSummaryForLast7Days() {
//   DateTime now = DateTime.now();
//   DateTime startDate = now.subtract(Duration(days: 6)); // Start from 6 days ago

//   double totalHours = 0;
//   int totalMinutes = 0;
//   int streak = 0;

//   // Retrieve the pomodoro data
//   var pomodoroData = storage.getItem('pomodoroData');

//   // Ensure pomodoroData is a List
//   List<Map<String, dynamic>> pomodoroList;
//   if (pomodoroData is List) {
//     pomodoroList = List<Map<String, dynamic>>.from(pomodoroData);
//   } else if (pomodoroData is String) {
//     // If it's a string, try to parse it as JSON
//     try {
//       var decoded = json.decode(pomodoroData);
//       if (decoded is List) {
//         pomodoroList = List<Map<String, dynamic>>.from(decoded);
//       } else {
//         print('Decoded pomodoroData is not a List');
//         return {'totalHours': totalHours, 'totalMinutes': totalMinutes, 'streak': streak};
//       }
//     } catch (e) {
//       print('Error parsing pomodoroData: $e');
//       return {'totalHours': totalHours, 'totalMinutes': totalMinutes, 'streak': streak};
//     }
//   } else {
//     print('pomodoroData is neither a List nor a String');
//     return {'totalHours': totalHours, 'totalMinutes': totalMinutes, 'streak': streak};
//   }

//   // Iterate through the last 7 days
//   for (int i = 0; i < 7; i++) {
//     DateTime currentDate = startDate.add(Duration(days: i));
//     String dateKey = "${currentDate.year}/${currentDate.month}/${currentDate.day}";

//     // Find sessions for the current date
//     List<dynamic> todaySessions = [];
//     for (var dayData in pomodoroList) {
//       if (dayData.containsKey(dateKey)) {
//         todaySessions = dayData[dateKey];
//         break;
//       }
//     }

//     int totalMilliseconds = 0;

//     // Iterate through the sessions for the current date
//     for (var session in todaySessions) {
//       if (session is Map<String, dynamic>) {
//         int? startTime = session["startTime"] is int ? session["startTime"] as int? : null;
//         int? stopTime = session["stopTime"] is int ? session["stopTime"] as int? : null;

//         // Only count completed sessions
//         if (startTime != null && stopTime != null && stopTime != -1) {
//           totalMilliseconds += (stopTime - startTime);
//         }
//       }
//     }

//     // Convert total time to hours and minutes
//     double todayHours = totalMilliseconds / (1000 * 60 * 60);
//     totalHours += todayHours;
//     totalMinutes += (todayHours * 60).toInt();

//     // Increase streak if there were any Pomodoro sessions today
//     if (todayHours > 0) {
//       streak++;
//     }
//   }

//   // Return the result as a map
//   return {
//     'totalHours': totalHours,
//     'totalMinutes': totalMinutes,
//     'streak': streak,
//   };
// }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              const Text(
                "Today's Analytics",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                ),
              ),
              Text(
                DateFormat('EEE, MMM d, yyyy').format(DateTime.now()),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${getPomodorosForToday()}/16',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              color: const Color.fromARGB(255, 0, 0, 0),
                              value: getPomodorosForToday() >= 16
                                  ? 16.0
                                  : getPomodorosForToday().toDouble(),
                              title: '',
                              radius: 25,
                            ),
                            PieChartSectionData(
                              color: Color.fromARGB(255, 222, 222, 222)!,
                              value: getPomodorosForToday() >= 16
                                  ? 0
                                  : 16 - getPomodorosForToday().toDouble(),
                              title: '',
                              radius: 25,
                            ),
                          ],
                          sectionsSpace: 0,
                          centerSpaceRadius: 70,
                          startDegreeOffset:
                              -90, // This makes the chart start from the top
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Text(
                  '${getTotalPomodoroHoursForToday()} hrs',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... [previous widgets remain the same] ...

                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatColumn("0", 'Total hours'),
                          _buildStatColumn('0', 'Streak'),
                          _buildStatColumn('2', 'Total Min'),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 270, // Increased height to accommodate legend
                      child: LineChart(
                        LineChartData(
                          gridData:
                              FlGridData(show: true, drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  // Get the Pomodoro data once
                                  Map<String, double> pomodoroData =
                                      getLast7DaysPomodoroHours();

                                  // Extract the days (dates) and sort them in ascending order
                                  List<String> days = pomodoroData.keys.toList()
                                    ..sort((a, b) {
                                      // Parse the date strings 'day/month' to compare them
                                      List<int> aParts =
                                          a.split('/').map(int.parse).toList();
                                      List<int> bParts =
                                          b.split('/').map(int.parse).toList();

                                      DateTime aDate = DateTime(
                                          2024,
                                          aParts[1],
                                          aParts[
                                              0]); // Assume current year or adjust as needed
                                      DateTime bDate =
                                          DateTime(2024, bParts[1], bParts[0]);

                                      return aDate.compareTo(
                                          bDate); // Sort in ascending order
                                    });

                                  // Now days are sorted from earliest to latest
                                  if (value.toInt() < days.length) {
                                    return Text(days[value.toInt()],
                                        style: TextStyle(fontSize: 11));
                                  }

                                  return Text(
                                      ''); // Return an empty text widget if index is out of bounds
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toInt()}h',
                                      style: TextStyle(fontSize: 11));
                                },
                                reservedSize: 30,
                              ),
                            ),
                            topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: 8,
                          lineBarsData: [
                            LineChartBarData(
                              spots: getLast7DaysPomodoroHours()
                                  .entries
                                  .map((entry) {
                                int index = getLast7DaysPomodoroHours()
                                    .keys
                                    .toList()
                                    .indexOf(entry.key); // Get the index
                                double hours = entry.value; // Get the hours
                                return FlSpot(index.toDouble(),
                                    hours); // Create FlSpot with index and hours
                              }).toList(), // Convert the map result to a list

                              isCurved: true,
                              color: Color.fromARGB(255, 0, 0, 0),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color.fromARGB(255, 0, 0, 0)
                                      .withOpacity(0.2)),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: Color.fromARGB(255, 56, 56, 56),
                              getTooltipItems:
                                  (List<LineBarSpot> touchedBarSpots) {
                                return touchedBarSpots.map((barSpot) {
                                  final flSpot = barSpot;
                                  return LineTooltipItem(
                                    '${flSpot.y}h',
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 0, 0, 0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Productive Hours',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
