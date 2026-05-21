import urllib.request
import urllib.parse
import json

def main():
    client_id = "iZsnndsk4IpT7w1k1R4t9JqU26gWcoGL" # public working client ID
    query = "chillin"
    
    url = f"https://api-v2.soundcloud.com/search/tracks?q={urllib.parse.quote(query)}&client_id={client_id}&limit=5"
    print("Fetching URL:", url)
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            data = response.read()
            res = json.loads(data.decode('utf-8'))
            print("Successfully received data!")
            print("Total collection items:", len(res.get("collection", [])))
            for i, track in enumerate(res.get("collection", [])[:3]):
                print(f"Track {i+1}:")
                print("  ID:", track.get("id"))
                print("  Title:", track.get("title"))
                print("  User username:", track.get("user", {}).get("username"))
                print("  Artwork URL:", track.get("artwork_url"))
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    main()
