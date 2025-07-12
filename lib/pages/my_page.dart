import 'package:flutter/material.dart';
import 'package:video_together/services/watch_history_service.dart';

import 'GalleryPage.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('播放历史', style: TextStyle(fontSize: 16, color: Colors.blue)),
                TextButton(
                  onPressed: () async {
                    await WatchHistoryService.clearAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('播放历史记录已清空')),
                    );
                  },
                  child: const Text('清空历史', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('我的下载'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('本地视频'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResourceGalleryPage(),
                  ),
                );
                },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('追剧与收藏'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('意见反馈'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('我的设置'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}