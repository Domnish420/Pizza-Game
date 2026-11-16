#!/usr/bin/env python3
"""Bundle the game into a single self-contained HTML fragment (dist/crust-empire.html)."""
import os, re
root = os.path.dirname(os.path.abspath(__file__))
rd = lambda p: open(os.path.join(root, p), encoding='utf-8').read()
html = rd('index.html')
body = re.search(r'<body>(.*?)<script', html, re.S).group(1).strip()
js = '\n'.join(rd('js/' + f) for f in ['data.js', 'game.js', 'ui.js', 'service.js'])
out = f'''<title>Crust Empire</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@500;700;800&display=swap">
<style>
{rd('css/style.css')}
</style>
{body}
<script>
{js}
boot();
</script>
'''
os.makedirs(os.path.join(root, 'dist'), exist_ok=True)
open(os.path.join(root, 'dist', 'crust-empire.html'), 'w', encoding='utf-8').write(out)
print('wrote dist/crust-empire.html', len(out), 'bytes')
