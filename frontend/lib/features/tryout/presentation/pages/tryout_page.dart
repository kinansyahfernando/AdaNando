import 'dart:async';
import 'package:flutter/material.dart';
import '../../../result/presentation/pages/result_page.dart'; // Path disesuaikan

class TryoutPage extends StatefulWidget {
  const TryoutPage({super.key});

  @override
  State<TryoutPage> createState() => _TryoutPageState();
}

class _TryoutPageState extends State<TryoutPage> {
  Timer? _timer;
  int _remainingSeconds = 3600; // 1 jam

  final List<Map<String, dynamic>> _questions = [
    {
      'id': 1,
      'question': 'Jika 2x + 3 = 11, berapakah nilai x?',
      'options': ['2', '3', '4', '5', '6'],
    },
    {
      'id': 2,
      'question': 'Sinonim dari kata "Paradoks" adalah...',
      'options': ['Kesamaan', 'Pertentangan', 'Perumpamaan', 'Penegasan', 'Penyimpangan'],
    },
  ];

  final Map<int, int> _answerKeys = {
    1: 2, // C
    2: 1, // B
  };

  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _showTimeUpDialog();
      }
    });
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Waktu Habis!'),
        content: const Text('Waktu ujian telah selesai. Jawabanmu akan dikumpulkan.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processResult();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _processResult() {
    int correct = 0;
    int wrong = 0;
    int empty = 0;
    double score = 0;

    for (var q in _questions) {
      int qId = q['id'];
      if (!_selectedOptions.containsKey(qId)) {
        empty++;
      } else if (_selectedOptions[qId] == _answerKeys[qId]) {
        correct++;
        score += 4; // IRT: Benar +4
      } else {
        wrong++;
        score -= 1; // IRT: Salah -1
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          totalQuestions: _questions.length,
          correctAnswers: correct,
          wrongAnswers: wrong,
          emptyAnswers: empty,
          finalScore: score,
        ),
      ),
    );
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Soal ${_currentQuestionIndex + 1} dari ${_questions.length}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                _formattedTime,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.yellow),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentQuestion['question'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: currentQuestion['options'].length,
                itemBuilder: (context, index) {
                  final optionText = currentQuestion['options'][index];
                  final isSelected = _selectedOptions[currentQuestion['id']] == index;

                  return Card(
                    color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RadioListTile<int>(
                      title: Text('${String.fromCharCode(65 + index)}. $optionText'),
                      value: index,
                      groupValue: _selectedOptions[currentQuestion['id']],
                      onChanged: (value) {
                        setState(() {
                          _selectedOptions[currentQuestion['id']] = value!;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _currentQuestionIndex > 0
                      ? () {
                          setState(() {
                            _currentQuestionIndex--;
                          });
                        }
                      : null,
                  child: const Text('Sebelumnya'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_currentQuestionIndex == _questions.length - 1) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Selesai Ujian?'),
                          content: const Text('Apakah kamu yakin ingin mengumpulkan jawaban?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _processResult();
                              },
                              child: const Text('Kumpulkan'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      setState(() {
                        _currentQuestionIndex++;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentQuestionIndex == _questions.length - 1 ? Colors.green : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_currentQuestionIndex == _questions.length - 1 ? 'Kumpulkan' : 'Selanjutnya'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}