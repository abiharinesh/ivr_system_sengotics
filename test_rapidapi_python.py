import requests
import json
import os
import time

urls = [
    'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744464.2727329_0.mp3',
    'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744617.3352439_0.mp3'
]

api_url = "https://speech-to-text-ai.p.rapidapi.com/transcribe"

headers = {
    "x-rapidapi-host": "speech-to-text-ai.p.rapidapi.com",
    "x-rapidapi-key": "0b05af13f3msh93eb0af75f27324p125ecfjsn27867461b99b"
}

for idx, url in enumerate(urls):
    print(f"\nProcessing URL: {url}")
    # Download file First
    local_filename = f"exotel_{idx}.mp3"
    print(f"Downloading to {local_filename}...")
    try:
        response = requests.get(url, stream=True, timeout=15)
        response.raise_for_status()
        with open(local_filename, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print("Download complete.")
    except Exception as e:
        print(f"Failed to download {url}: {e}")
        continue
    
    # Upload to RapidAPI
    print("Uploading to RapidAPI for translation...")
    try:
        with open(local_filename, 'rb') as f:
            files = { "file": (local_filename, f, "audio/mpeg") }
            data = {
                "task": "translate",
            }
            res = requests.post(api_url, data=data, files=files, headers=headers)
            res.raise_for_status()
            print("Translation Response:\n", json.dumps(res.json(), indent=2))
    except Exception as e:
        print(f"Failed to transcribe: {e}")
        if hasattr(e, 'response') and e.response is not None:
             print(e.response.text)
    
    # Clean up
    if os.path.exists(local_filename):
        os.remove(local_filename)
