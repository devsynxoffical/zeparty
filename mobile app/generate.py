import urllib.request, json
try:
    req = urllib.request.Request('https://restcountries.com/v3.1/all?fields=name,cca2,flag', headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        countries = []
        for c in data:
            if 'flag' in c and 'cca2' in c and 'name' in c and 'common' in c['name']:
                countries.append({'code': c['cca2'], 'name': c['name']['common'], 'flag': c['flag']})
        countries.sort(key=lambda x: x['name'])
        with open('all_countries.txt', 'w', encoding='utf-8') as f:
            f.write('  final List<Map<String, String>> _countries = [\n')
            for c in countries:
                name = c['name'].replace(\"'\", \"\\\\'\")
                f.write(f\"    {{'code': '{c['code']}', 'name': '{name}', 'flag': '{c['flag']}'}},\n\")
            f.write(\"    {'code': 'GLOBAL', 'name': 'Global', 'flag': '🌍'},\n\")
            f.write('  ];\n')
except Exception as e:
    print(e)
