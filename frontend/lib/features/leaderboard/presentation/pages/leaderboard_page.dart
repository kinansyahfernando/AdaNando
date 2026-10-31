import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> dummyLeaderboard = [
      {'rank': 1, 'name': 'Budi Santoso', 'score': 850.50, 'isCurrentUser': false},
      {'rank': 2, 'name': 'Siti Aminah', 'score': 820.00, 'isCurrentUser': false},
      {'rank': 3, 'name': 'Andi Wijaya', 'score': 800.00, 'isCurrentUser': true},
      {'rank': 4, 'name': 'Rina Melati', 'score': 780.50, 'isCurrentUser': false},
      {'rank': 5, 'name': 'Joko Susilo', 'score': 750.00, 'isCurrentUser': false},
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Peringkat Try Out'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Top 5 Pejuang UTBK',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: dummyLeaderboard.length,
                itemBuilder: (context, index) {
                  final data = dummyLeaderboard[index];
                  final rank = data['rank'];
                  final isCurrentUser = data['isCurrentUser'];

                  return Card(
                    elevation: isCurrentUser ? 4 : 1,
                    color: isCurrentUser ? Colors.blue.withOpacity(0.1) : Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isCurrentUser ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: _buildRankIcon(rank),
                      title: Text(
                        data['name'],
                        style: TextStyle(
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentUser ? Colors.blue : Colors.black,
                        ),
                      ),
                      trailing: Text(
                        data['score'].toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: rank == 1 ? Colors.amber[700] : Colors.blue,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankIcon(int rank) {
    if (rank == 1) {
      return const Icon(Icons.emoji_events, color: Colors.amber, size: 40);
    } else if (rank == 2) {
      return const Icon(Icons.emoji_events, color: Colors.grey, size: 35);
    } else if (rank == 3) {
      return const Icon(Icons.emoji_events, color: Colors.brown, size: 30);
    } else {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        child: Text(
          rank.toString(),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}