import os
import subprocess
from flask import Flask, request, redirect, url_for, render_template_string, send_from_directory, abort

# --- Config ---
BASE = os.path.dirname(__file__)
UPLOAD_FOLDER = os.path.join(BASE, "videos")
ALLOWED = {"mp4", "mkv", "avi", "mov"}
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
# Max upload size: 1GB (adjust as you like)
app.config["MAX_CONTENT_LENGTH"] = 1024 * 1024 * 1024

# Track the currently running media player process
PLAYER = None

# --- Helpers ---
def have(cmd: str) -> bool:
    from shutil import which
    return which(cmd) is not None

def player_cmd(path: str, loop: bool = False):
    """
    Build the player command for this device.
    Prefer omxplayer on Pi Zero (fastest), fallback to VLC's CLI (cvlc).
    """
    if have("omxplayer"):
        base = ["omxplayer", "--adev", "hdmi", "--no-osd"]
        if loop:
            base.append("--loop")
        return base + [path]
    elif have("cvlc"):
        # For loop we must NOT use --play-and-exit
        if loop:
            return ["cvlc", "--fullscreen", "--loop", "--no-video-title-show", path]
        else:
            return ["cvlc", "--fullscreen", "--play-and-exit", "--no-video-title-show", path]
    return None

def stop_player():
    global PLAYER
    if PLAYER and PLAYER.poll() is None:
        try:
            PLAYER.terminate()
        except Exception:
            pass
    PLAYER = None

def play_file(name: str, loop: bool = False) -> bool:
    """
    Stop any existing player, then start a new one for the given file.
    Returns True if the player was started successfully.
    """
    global PLAYER
    stop_player()
    path = os.path.join(UPLOAD_FOLDER, name)
    if not os.path.isfile(path):
        return False
    cmd = player_cmd(path, loop=loop)
    if not cmd:
        return False
    # Run detached so Flask remains responsive
    PLAYER = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return True

def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED

def list_videos():
    return sorted(
        f for f in os.listdir(UPLOAD_FOLDER)
        if os.path.isfile(os.path.join(UPLOAD_FOLDER, f))
    )

# --- HTML ---
HTML = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Pi Video Server</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body{font-family:sans-serif;max-width:820px;margin:0 auto;padding:16px}
    h1{text-align:center}
    .row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
    .item{display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #ddd;padding:8px 0}
    .name{word-break:break-all}
    button{padding:6px 10px}
    .upload{border:1px solid #ddd;padding:12px;margin:12px 0}
    .hint{color:#555;font-size:.9em}
  </style>
</head>
<body>
  <h1>Pi Video Server</h1>

  <div class="upload">
    <h3>Upload video</h3>
    <form method="post" enctype="multipart/form-data" action="{{ url_for('upload') }}">
      <input type="file" name="file" accept="video/*" required>
      <button type="submit">Upload</button>
    </form>
    <p class="hint">Allowed: mp4, mkv, avi, mov</p>
  </div>

  <div class="row">
    <form method="post" action="{{ url_for('stop') }}"><button type="submit">Stop Playback</button></form>
  </div>

  <h3>Available videos ({{ videos|length }})</h3>
  {% if not videos %}<p>No videos yet.</p>{% endif %}
  {% for v in videos %}
    <div class="item">
      <span class="name">{{ v }}</span>
      <div class="row">
        <form method="post" action="{{ url_for('play', name=v) }}"><button type="submit">Play</button></form>
        <form method="post" action="{{ url_for('play_loop', name=v) }}"><button type="submit">Loop</button></form>
        <a href="{{ url_for('download', name=v) }}"><button type="button">Download</button></a>
        <form method="post" action="{{ url_for('delete', name=v) }}" onsubmit="return confirm('Delete {{ v }}?')">
          <button type="submit">Delete</button>
        </form>
      </div>
    </div>
  {% endfor %}
</body>
</html>"""

# --- Routes ---
@app.route("/", methods=["GET"])
def index():
    return render_template_string(HTML, videos=list_videos())

@app.route("/upload", methods=["POST"])
def upload():
    f = request.files.get("file")
    if not f or f.filename == "":
        return redirect(url_for("index"))
    if not allowed_file(f.filename):
        return "File type not allowed", 400
    dest = os.path.join(UPLOAD_FOLDER, os.path.basename(f.filename))
    f.save(dest)
    return redirect(url_for("index"))

@app.route("/play/<name>", methods=["POST"])
def play(name):
    return redirect(url_for("index")) if play_file(name, loop=False) else ("Could not start player", 500)

@app.route("/play_loop/<name>", methods=["POST"])
def play_loop(name):
    return redirect(url_for("index")) if play_file(name, loop=True) else ("Could not start player", 500)

@app.route("/stop", methods=["POST"])
def stop():
    stop_player()
    return redirect(url_for("index"))

@app.route("/delete/<name>", methods=["POST"])
def delete(name):
    path = os.path.join(UPLOAD_FOLDER, name)
    if os.path.isfile(path):
        os.remove(path)
    return redirect(url_for("index"))

@app.route("/videos/<name>", methods=["GET"])
def download(name):
    path = os.path.join(UPLOAD_FOLDER, name)
    if not os.path.isfile(path):
        abort(404)
    return send_from_directory(UPLOAD_FOLDER, name, as_attachment=True)

# --- Main ---
if __name__ == "__main__":
    # Autoplay the first video in loop when the app starts
    videos = list_videos()
    if videos:
        print(f"Auto-playing first video: {videos[0]}")
        play_file(videos[0], loop=True)
    else:
        print("No videos found to autoplay")
    
    # Bind to all interfaces so clients on your Wi-Fi/AP can reach it
    app.run(host="0.0.0.0", port=8000, debug=False)
