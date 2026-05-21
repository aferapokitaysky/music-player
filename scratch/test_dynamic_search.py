import urllib.request
import urllib.parse
import json
import re
import ssl

def main():
    # Bypass SSL verification
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
    
    # 1. Fetch soundcloud.com homepage
    req = urllib.request.Request("https://soundcloud.com", headers=headers)
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            html = response.read().decode('utf-8')
    except Exception as e:
        print("Failed to load soundcloud.com homepage:", e)
        return
        
    # 2. Extract script URLs
    js_urls = re.findall(r'https://a-v2\.sndcdn\.com/assets/[^"\']+\.js', html)
    print("Found JS URLs:", len(js_urls))
    
    client_id = None
    # Scan from the last script backwards
    for js_url in reversed(js_urls):
        print("Scanning script:", js_url)
        js_req = urllib.request.Request(js_url, headers=headers)
        try:
            with urllib.request.urlopen(js_req, context=ctx) as js_res:
                js_content = js_res.read().decode('utf-8')
                match = re.search(r'client_id\s*[:=]\s*"([A-Za-z0-9]{20,})"', js_content)
                if match:
                    client_id = match.group(1)
                    print("Successfully extracted client_id:", client_id)
                    break
        except Exception as e:
            print("Failed to load script:", e)
            
    if not client_id:
        print("Failed to extract client_id. Using a known fallback...")
        client_id = "YUKiah45Qso1j3x49cgN8sUjL8H1zQxP"
        
    # 3. Perform the search
    search_url = f"https://api-v2.soundcloud.com/search/tracks?q={urllib.parse.quote('chillin')}&client_id={client_id}&limit=3"
    print("Fetching search results:", search_url)
    search_req = urllib.request.Request(search_url, headers=headers)
    try:
        with urllib.request.urlopen(search_req, context=ctx) as s_res:
            res_data = s_res.read()
            res = json.loads(res_data.decode('utf-8'))
            print("Successfully received search data!")
            for i, track in enumerate(res.get("collection", [])):
                print(f"Track {i+1}: {track.get('title')} by {track.get('user', {}).get('username')} (ID: {track.get('id')})")
    except Exception as e:
        print("Search failed:", e)

if __name__ == "__main__":
    main()
