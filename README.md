script to download YouTube audio and convert it to MP3s for older devices (like MP3 players)

### how does it work
1. Put YouTube links in `links.txt` (one per line).
2. Run the script:
   ```bash
   chmod +x ./process_links.sh
   ./process_links.sh
   ```

### where does it go
- **MP3s:** Saved in the `./converts` folder.
- **Originals:** Saved in the `./videos` folder.

### what you need
you need these installed on your system:
- `yt-dlp`
- `ffmpeg`
- `jq`
