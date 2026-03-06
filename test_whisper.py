import os
import requests

def test_whisper():
    urls = [
        "https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744617.3352439_0.mp3",
        "https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744464.2727329_0.mp3"
    ]
    
    exotel_key = os.environ.get("EXOTEL_API_KEY")
    exotel_token = os.environ.get("EXOTEL_API_TOKEN")
    groq_key = os.environ.get("GROQ_API_KEY")
    
    auth = (exotel_key, exotel_token) if exotel_key and exotel_token else None
    
    for i, url in enumerate(urls):
        print(f"\n=== Processing Audio {i+1} ===")
        print(f"URL: {url}")
        
        # Download
        print("Downloading...")
        resp = requests.get(url, auth=auth)
        if resp.status_code != 200:
            print(f"Download failed: {resp.status_code}")
            continue
            
        with open(f"temp{i}.mp3", "wb") as f:
            f.write(resp.content)
            
        # Transcribe
        print("Sending to Whisper...")
        headers = {"Authorization": f"Bearer {groq_key}"}
        
        with open(f"temp{i}.mp3", "rb") as f:
            files = {
                "file": (f"temp{i}.mp3", f, "audio/mpeg"),
                "model": (None, "whisper-large-v3")
            }
            res = requests.post("https://api.groq.com/openai/v1/audio/transcriptions", headers=headers, files=files)
            
        print("\n--- Transcription Result ---")
        if res.status_code == 200:
            print(res.json().get("text", ""))
        else:
            print(f"Error: {res.status_code} - {res.text}")
        print("----------------------------\n")
        
        os.remove(f"temp{i}.mp3")

if __name__ == "__main__":
    test_whisper()
