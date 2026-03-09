# Raspberry Pi Zero Video Server

A Flask-based video server for Raspberry Pi Zero that allows you to upload, play, and manage videos through a web interface.

## Features

- **Autoplay on Boot**: Automatically plays the first video in loop when the app starts
- **Web Interface**: Upload, play, loop, download, and delete videos
- **Remote Control**: Access from any device on the same network
- **Video Looping**: Play videos continuously in loop mode
- **Multiple Formats**: Supports MP4, MKV, AVI, and MOV files

## Network Configuration

- **Port**: `8000`
- **Access URL**: `http://<pi-ip-address>:8000`

## Installation

1. Clone the repository on your Raspberry Pi Zero 2 W:
   ```bash
   git clone https://github.com/jenschristianschroder/video_server.git
   cd video_server
   ```

2. Run the setup script:
   ```bash
   sudo ./setup.sh
   ```

   This will:
   - Install system packages (Python 3, VLC)
   - Create a Python virtual environment and install dependencies
   - Create a `videos/` directory
   - Install and enable a systemd service so the app starts automatically on boot

3. Manage the service:
   ```bash
   sudo systemctl status video-server
   sudo systemctl restart video-server
   sudo systemctl stop video-server
   journalctl -u video-server -f   # view logs
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

The setup script installs a systemd service (`video-server`) that starts the app automatically on boot. No manual configuration is needed.

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
├── setup.sh            # One-time install & systemd setup
├── requirements.txt    # Python dependencies
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

## Maintenance

The video server runs as a systemd service. **Always stop the service before performing maintenance** to ensure the video player subprocess is cleanly terminated.

### Stopping the service for maintenance

```bash
sudo systemctl stop video-server
```

This cleanly shuts down both the Flask web server and any running video player process. Your terminal will be free for normal use.

### Performing system updates

```bash
sudo systemctl stop video-server
sudo apt-get update && sudo apt-get upgrade -y
sudo systemctl start video-server
```

### Changing settings

Edit the `.env` file to change autoplay behaviour:

```bash
sudo systemctl stop video-server
nano .env                          # e.g. AUTOPLAY_ON_START=false
sudo systemctl start video-server
```

The default video can also be changed from the web interface without stopping the service.

### Restarting the service

```bash
sudo systemctl restart video-server
```

### Viewing logs

```bash
journalctl -u video-server -f
```

### Starting after maintenance

```bash
sudo systemctl start video-server
```

The service will also start automatically on the next reboot.

## Troubleshooting

### No video plays on startup
- Ensure videos exist in the `videos/` folder
- Check that VLC is installed: `which cvlc`
- Check logs: `journalctl -u video-server -f`

### Cannot access web interface
- Confirm the Pi's IP address with `hostname -I`
- Ensure the Pi is connected to WiFi
- Check that the service is running: `sudo systemctl status video-server`

### Video playback issues
- Ensure video format is supported (MP4, MKV, AVI, MOV)
- Check that HDMI output is properly connected

### Terminal appears polluted or unresponsive
This can happen if the service was killed without properly terminating the video player subprocess. To recover:

```bash
# Kill any orphaned player processes
sudo pkill -9 cvlc 2>/dev/null; sudo pkill -9 vlc 2>/dev/null
sudo pkill -9 omxplayer 2>/dev/null

# Restart the service cleanly
sudo systemctl restart video-server
```

## Notes

- The app uses omxplayer (preferred on Pi Zero) or VLC for video playback
- Videos play fullscreen on the connected display
- Only one video can play at a time
- Uploading a new video does not interrupt current playback
