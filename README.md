# Raspberry Pi Zero Video Server

A Flask-based video server for Raspberry Pi Zero that allows you to upload, play, and manage videos through a web interface.

## Features

- **Autoplay on Boot**: Automatically plays the first video in loop when the app starts
- **Web Interface**: Upload, play, loop, download, and delete videos
- **Remote Control**: Access from any device on the same network
- **Video Looping**: Play videos continuously in loop mode
- **Multiple Formats**: Supports MP4, MKV, AVI, and MOV files

## Network Configuration

- **IP Address**: `10.57.175.38`
- **WiFi Network**: `MSFTDEVICES`
- **Port**: `8000`
- **Access URL**: `http://10.57.175.38:8000`

## Credentials

- **Username**: `hubcph`
- **Password**: hub password

## Installation

1. Clone or copy this repository to your Raspberry Pi Zero
2. Install required dependencies:
   ```bash
   pip install flask
   ```

3. Ensure video player is installed:
   ```bash
   sudo apt-get install omxplayer
   ```
   Or alternatively:
   ```bash
   sudo apt-get install vlc
   ```

## Usage

### Starting the Server

Run the application:
```bash
python app.py
```

The server will:
1. Automatically play the first video in the `videos/` folder (in loop mode)
2. Start the web server on port 8000
3. Be accessible at `http://10.57.175.38:8000`

### Autoplay on Boot

To run the video server automatically when the Raspberry Pi boots, add to `/etc/rc.local` (before `exit 0`):
```bash
cd /path/to/video_server && python app.py &
```

Or create a systemd service for better control.

### Web Interface

Access the web interface from any device on the MSFTDEVICES network:
- **Upload**: Select a video file and click Upload
- **Play**: Play a video once
- **Loop**: Play a video continuously
- **Stop**: Stop current playback
- **Download**: Download a video to your device
- **Delete**: Remove a video from the server

## File Structure

```
video_server/
├── app.py              # Main Flask application
├── autoplay_video.py   # Standalone autoplay script
├── videos/             # Video storage folder
└── README.md           # This file
```

## Supported Video Formats

- MP4
- MKV
- AVI
- MOV

## Configuration

### Upload Size Limit
Default: 1GB per file. Modify in `app.py`:
```python
app.config["MAX_CONTENT_LENGTH"] = 1024 * 1024 * 1024  # bytes
```

### Port
Default: 8000. Modify in `app.py`:
```python
app.run(host="0.0.0.0", port=8000, debug=False)
```

## Troubleshooting

### No video plays on startup
- Ensure videos exist in the `videos/` folder
- Check that omxplayer or VLC is installed
- Check terminal output for error messages

### Cannot access web interface
- Verify Raspberry Pi is connected to MSFTDEVICES WiFi
- Confirm IP address is `10.57.175.38` with `hostname -I`
- Check firewall settings if enabled

### Video playback issues
- Ensure video format is supported
- Check that HDMI output is properly connected
- For omxplayer, audio defaults to HDMI output

## Notes

- The app uses omxplayer (preferred on Pi Zero) or VLC for video playback
- Videos play fullscreen on the connected display
- Only one video can play at a time
- Uploading a new video does not interrupt current playback
