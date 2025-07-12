import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'loading_page.dart';
import 'models/watch_history.dart';
import 'models/playlist.dart'; // 添加这行
import 'pages/bottom_navigation.dart';
import 'dart:io'; // 添加这行

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  await Hive.initFlutter();

  // 注册所有适配器
  Hive.registerAdapter(WatchHistoryAdapter());
  Hive.registerAdapter(PlaylistAdapter());      // 添加这行
  Hive.registerAdapter(PlaylistItemAdapter());  // 添加这行

  // 打开需要的盒子
  await Hive.openBox<WatchHistory>('watchHistory');
  await Hive.openBox<Playlist>('playlists');    // 添加这行

  // 解决 OpenGL ES API 错误
  if (Platform.isAndroid) {
    debugPrint('OpenGL ES workaround applied');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '视频一起看',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => const LoadingPage(),
        '/pages': (context) => const BottomNavigation(),
      },
    );
  }
}