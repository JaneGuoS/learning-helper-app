import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/workflow_provider.dart';
import 'ui/screens/problem_solver_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkflowProvider()),
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
      title: 'AI Workflow Editor',
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const ProblemSolverScreen(),
    );
  }
}