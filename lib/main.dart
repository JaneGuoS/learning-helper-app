import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workflow_provider.dart';
import 'providers/plan_provider.dart'; // Import Plan Provider
import 'ui/screens/problem_solver_screen.dart';
import 'ui/screens/learning_plan_screen.dart';

import 'providers/resource_provider.dart';
import 'ui/screens/resources_screen.dart'; // Import

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => ResourceProvider()), // ADD THIS
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Learning Agent',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(), // Use Wrapper Screen
    );
  }
}

// Wrapper for Bottom Navigation
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ProblemSolverScreen(),
    const LearningPlanScreen(),
    const ResourcesScreen(), // ADD THIS
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.psychology), label: 'Problem Solver'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Learning Plan'),
          NavigationDestination(icon: Icon(Icons.folder_copy), label: 'Resources'), // ADD THIS
        ],
      ),
    );
  }
}