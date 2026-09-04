// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse('https://restcountries.com/v3.1/all'));
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    final decoded = json.decode(responseBody);
    if (decoded is! List) {
      print('Not a list: $decoded');
      return;
    }
    final List<dynamic> data = decoded;
    final countries = <Map<String, String>>[];
    
    for (var c in data) {
      if (c['flag'] != null && c['cca2'] != null && c['name'] != null && c['name']['common'] != null) {
        countries.add({
          'code': c['cca2'],
          'name': c['name']['common'],
          'flag': c['flag']
        });
      }
    }
    
    countries.sort((a, b) => a['name']!.compareTo(b['name']!));
    
    final file = File('all_countries.txt');
    final sink = file.openWrite();
    sink.writeln('  final List<Map<String, String>> _countries = [');
    for (var c in countries) {
      final name = c['name']!.replaceAll("'", "\\'");
      sink.writeln("    {'code': '${c['code']}', 'name': '$name', 'flag': '${c['flag']}'},");
    }
    sink.writeln("    {'code': 'GLOBAL', 'name': 'Global', 'flag': '🌍'},");
    sink.writeln('  ];');
    await sink.close();
    print('Done');
  } catch (e) {
    print(e);
  }
}
