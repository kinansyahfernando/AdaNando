import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int emptyAnswers;
  final double finalScore;

  const ResultPage({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.emptyAnswers,
    required this.finalScore,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Hasil Try Out'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
              const SizedBox(height: 20),
              const Text(
                'Ujian Selesai!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Skor Akhir Kamu:',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Text(
                finalScore.toStringAsFixed(2),
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    _buildRow('Total Soal', totalQuestions.toString(), Colors.black),
                    const Divider(),
                    _buildRow('Jawaban Benar (+4)', correctAnswers.toString(), Colors.green),
                    const Divider(),
                    _buildRow('Jawaban Salah (-1)', wrongAnswers.toString(), Colors.red),
                    const Divider(),
                    _buildRow('Tidak Dijawab (0)', emptyAnswers.toString(), Colors.grey),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Kembali ke Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}