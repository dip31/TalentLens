import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/db_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = DbService().getLeaderboard('squats');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard - Squats'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No results yet'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              final metrics = jsonDecode(r['metrics'] as String) as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(child: Text('${i+1}')),
                title: Text(r['name'] as String? ?? 'User'),
                subtitle: Text('Reps: ${metrics['reps'] ?? '-'} | Valid: ${(r['validity_flag'] == 1) ? 'Yes' : 'No'} | Trial: ${r['trial_number']}'),
              );
            },
          );
        },
      ),
    );
  }
}


