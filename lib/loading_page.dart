import 'package:flutter/material.dart';
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      // 加载完成后跳转到主页
      Navigator.pushReplacementNamed(context, '/pages');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 设置背景图片
          Image.asset(
            'assets/images/load.jpg',
            fit: BoxFit.cover,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: null, // 持续滚动动画
                      color: Colors.yellow,
                      backgroundColor: Colors.grey[200]?.withOpacity(0.5),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '正在加载资源...',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}