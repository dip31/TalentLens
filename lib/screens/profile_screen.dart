import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('No user loaded'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(user.name),
                    subtitle: Text('Age: ${user.age}, ${user.gender}'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('Location'),
                    subtitle: Text(user.location),
                  ),
                ),
                const SizedBox(height: 12),
                if (user.preferredSports != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sports),
                      title: const Text('Preferred Sports'),
                      subtitle: Text(user.preferredSports!),
                    ),
                  ),
                const SizedBox(height: 12),
                if (user.govtId != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge),
                      title: const Text('Govt ID'),
                      subtitle: Text(user.govtId!),
                    ),
                  ),
              ],
            ),
    );
  }
}


