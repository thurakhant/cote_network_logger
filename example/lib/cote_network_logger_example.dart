import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:cote_network_logger/cote_network_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await startNetworkLogServer();
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final dio = Dio()..interceptors.add(const CoteNetworkLogger());
            await dio.get('https://jsonplaceholder.typicode.com/posts/1');
          },
          child: Text('Send GET'),
        ),
      ),
    ),
  ));
}
