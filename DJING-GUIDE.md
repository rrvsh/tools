# The Complete DJ's Guide to Music Collection Management
## For Mixxx + DDJ-FLX4 on NixOS & macOS

**Last Updated:** April 2026
**Target Setup:** NixOS (nemesis) + macOS Darwin (alpha) + Mixxx 2.5.6+ + Pioneer DDJ-FLX4

---

## Table of Contents

1. [System Setup](#1-system-setup)
2. [Music Acquisition Strategies](#2-music-acquisition-strategies)
3. [Automated Collection with Lidarr](#3-automated-collection-with-lidarr)
4. [Peer-to-Peer Discovery with Soulseek](#4-peer-to-peer-discovery-with-soulseek)
5. [File Organization & Metadata](#5-file-organization--metadata)
6. [Library Management in Mixxx](#6-library-management-in-mixxx)
7. [DDJ-FLX4 Controller Configuration](#7-ddj-flx4-controller-configuration)
8. [Cross-Device Synchronization](#8-cross-device-synchronization)
9. [Backup & Redundancy](#9-backup--redundancy)
10. [Maintenance Workflows](#10-maintenance-workflows)

---

## 1. System Setup

### Your Current Configuration

Based on your flake configuration, you have:
- **NixOS host:** `nemesis` (x86_64-linux, Hyprland, NVIDIA)
- **macOS host:** `alpha` (aarch64-darwin, nix-homebrew)
- **Mixxx installation:**
  - Linux: `pkgs.mixxx` via home-manager
  - macOS: Homebrew cask `mixxx`

### NixOS Configuration (nemesis)

Your existing setup already includes:
- ✅ PipeWire + WirePlumber for audio
- ✅ Hyprland with proper portal configuration
- ✅ Mixxx in home.packages (line 223 in `rafiq.nix`)

**No additional configuration needed** - Mixxx will work out of the box.

### macOS Configuration (alpha)

Your flake already installs Mixxx via Homebrew:
```nix
homebrew.casks = [ "ghostty" "mixxx" ];
```

### First-Time Setup

1. **Connect DDJ-FLX4** via USB
2. **Launch Mixxx:** `mixxx` from terminal or application launcher
3. **Initial wizard:** Select your music directory (create `~/0_library` if needed)
4. **Audio setup:**
   - Preferences → Sound
   - Interface: "Pioneer DJ DDJ-FLX4"
   - Master: Channels 1-2
   - Headphones: Channels 3-4
   - Sample rate: 44100 Hz
   - Buffer: 256 samples

---

## 2. Music Acquisition Strategies

### Overview

You have multiple options for building your library, from fully automated to manual curation. Here's the spectrum:

```
Fully Automated ← → Manual Curation
    Lidarr              Bandcamp purchases
    Soulseek            Beatport downloads
    (set & forget)      (direct artist support)
```

**Recommended approach:** Hybrid model combining automation with intentional purchases.

---

## 3. Automated Collection with Lidarr

### What is Lidarr?

Lidarr is a music collection manager that automatically monitors RSS feeds, interfaces with download clients, and organizes your library. Think of it as "Sonarr/Radarr for music" 😉

**Key features:**
- Automatic artist monitoring
- Quality profiles (MP3 → FLAC upgrades)
- Metadata management
- Download client integration

### Installation Options

#### Option A: Docker (Recommended for Isolation)

```bash
docker run -d \
  --name=lidarr \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Singapore \
  -p 8686:8686 \
  -v /path/to/config:/config \
  -v /home/rafiq/0_library:/music \
  -v /path/to/downloads:/downloads \
  --restart unless-stopped \
  lscr.io/linuxserver/lidarr:latest
```

#### Option B: NixOS Native

Add to your `nemesis.nix`:

```nix
services.lidarr = {
  enable = true;
  user = "rafiq";
  group = "users";
  dataDir = "/var/lib/lidarr";
  port = 8686;
};
```

*Note: Lidarr isn't in nixpkgs yet, so you'd need to use a community overlay or Docker.*

### Configuration Workflow

1. **Access Web UI:** `http://localhost:8686`
2. **Settings → Media Management:**
   - Root folder: `/home/rafiq/0_library`
   - Naming: `{Artist Name}/{Album Title}/{Track No:00} - {Track Title}`
3. **Settings → Quality Profiles:**
   - Create "DJ Quality" profile: FLAC + MP3-320
   - Enable "Upgrade Until: FLAC"
4. **Settings → Download Client:**
   - Add qBittorrent/Transmission for torrents
   - Or NZBGet for Usenet
5. **Settings → Indexers:**
   - Use Prowlarr as indexer manager (recommended)
   - Or add indexers directly

### Quality Profiles for DJing

| Profile Name | Formats | Upgrade Until | Min Size | Use Case |
|-------------|---------|---------------|----------|----------|
| **Standard** | MP3-320 | MP3-320 | 5 MB | Practice/library building |
| **High Quality** | FLAC, MP3-320 | FLAC | 20 MB | Performance library |
| **Audiophile** | FLAC only | FLAC | 25 MB | Archival/master copies |

### Automation Tips

- **Import Lists:** Follow artists from Last.fm, Spotify playlists
- **Calendar:** Monitor upcoming releases
- **Wanted → Missing:** Batch search for missing albums
- **Auto-tagging:** Enable metadata writing in Settings

### ⚠️ Important Considerations

**Legal:** Lidarr itself is legal software, but what you download depends on your sources. Use responsibly and comply with copyright laws in your jurisdiction 😉

**Storage:** FLAC files are ~100-150 MB per album. Plan accordingly:
- 1,000 albums ≈ 100-150 GB
- 10,000 albums ≈ 1-1.5 TB

---

## 4. Peer-to-Peer Discovery with Soulseek

### What is Soulseek?

Soulseek is a peer-to-peer file-sharing network focused on music, operating since 2001. It's particularly strong in electronic, underground, and rare recordings. The network has a dedicated community and is known for hard-to-find tracks 😉

**Characteristics:**
- 80,000-100,000 concurrent users
- Direct user-to-user transfers
- Folder-based sharing (complete albums)
- Chat rooms and community features
- Unencrypted protocol (use VPN)

### Nicotine+ Client Installation

**NixOS:**
```nix
# In your home-manager config (rafiq.nix)
home.packages = [ pkgs.nicotine-plus ];
```

**macOS:**
```nix
# In alpha.nix homebrew section
homebrew.casks = [ "nicotine-plus" ];
```

Or via Homebrew directly: `brew install nicotine-plus`

### Initial Setup

1. **Launch Nicotine+**
2. **Create account:** Choose unique username (recycled after 30 days inactive)
3. **Set password:** Required for login
4. **Configure shared folder:** Point to your music library
5. **Download directory:** Set to `~/Downloads/Soulseek` initially

### Search Techniques

**Basic syntax:**
```
artist album              # Both terms
blue suede -shoes         # Exclude "shoes"
pink*floyd                # Wildcard match
"exact phrase"            # Exact match
```

**Pro tips:**
- Search by folder name to find complete albums
- Sort results by bitrate for quality
- Browse users with good collections
- Use wishlist for automatic notifications

### Download Workflow

1. Search for artist/album
2. Review results (check user speed, file quality)
3. Right-click → "Download Containing Folder" (gets full album)
4. Files saved to download directory
5. Move to `0_library` and tag appropriately

### Community Etiquette

**Do:**
- ✅ Share files back (don't just leech)
- ✅ Be patient with queues
- ✅ Browse users you respect
- ✅ Use wishlist for discovery

**Don't:**
- ❌ Demand uploads
- ❌ Spam chat rooms
- ❌ Free-ride excessively
- ❌ Ban users abusively

### Privacy & Security

**⚠️ Soulseek is NOT anonymous:**
- Your IP is visible to users you connect with
- Username is public
- Shared folders are browsable by anyone

**Recommendations:**
- Use VPN (Tailscale is already configured on your systems!)
- Only share intended folders
- Scan downloaded files
- Don't include personal info in filenames

### Legal Considerations

Soulseek's ToS states users are responsible for copyright compliance. The network is for sharing files you're legally allowed to share 😉 Use discretion and common sense.

---

## 5. File Organization & Metadata

### Directory Structure

Based on your existing `lib` alias pointing to `~/0_library`:

```
/home/rafiq/0_library/          (nemesis)
/Users/rafiq/0_library/         (alpha)
├── 01_Incoming/                # New downloads (Lidarr/Soulseek)
├── 02_Processing/              # Being tagged/organized
├── 03_MainLibrary/             # Active DJ library
│   ├── By_Genre/
│   │   ├── House/
│   │   ├── Techno/
│   │   ├── Drum_and_Bass/
│   │   └── [other genres]
│   ├── By_Key/                 # Optional: Camelot organization
│   │   ├── 1A/ ... 12B/
│   │   └── Unanalyzed/
│   └── By_BPM_Range/           # Optional: BPM organization
│       ├── 100-120/
│       ├── 120-130/
│       └── [other ranges]
├── 04_Archive/                 # Unused tracks (external drive)
└── 05_Playlists/               # Exported M3U/XSPF playlists
```

### File Naming Convention

```
[Artist Name] - [Track Title] (Remix Name) [Label].flac

Examples:
01. John Summit - Where You Are (Original Mix) - Defected.flac
02. Fisher - Losing It (Extended Mix) - Catch & Release.flac
```

**Rules:**
- Title Case consistently
- Include remix in parentheses
- Add label for identification
- Avoid illegal characters: `/ \ : * ? " < > |`
- No leading/trailing spaces

### Metadata Standards

**Essential ID3 Tags (ID3v2.3 or v2.4):**

| Field | Content | Example |
|-------|---------|---------|
| **Title** | Track name | "Where You Are" |
| **Artist** | Primary artist | "John Summit" |
| **Album** | EP/Album name | "Where You Are EP" |
| **Genre** | Specific genre | "Deep House" |
| **Year** | Release year | "2024" |
| **BPM** | Beats per minute | "124.5" |
| **Key** | Camelot notation | "8A" |
| **Comments** | DJ-specific tags | "#opener #sunset #melodic" |

### DJ-Specific Tagging System

Use the **Comments** field for searchable tags:

```
#opener #peaktime #midnight #bassline #vocal #festival #rave #transition #banger #warmup #closer
```

**Best practices:**
- Prefix with `#` for easy identification
- Create consistent, memorable tags
- Use numbers for ordering: `#RaveTrap1`, `#RaveTrap2`
- Tags travel with files across DJ software

### Tools for Tag Management

**Kid3 (Cross-platform, recommended):**
```nix
# Add to both nemesis.nix and alpha.nix
home.packages = [ pkgs.kid3 ];
```

**Mp3tag (Windows only, if needed)**

**Picard (MusicBrainz auto-tagging):**
```nix
home.packages = [ pkgs.musicbrainz-picard ];
```

### Pre-Import Checklist

For each track before adding to Mixxx:
- [ ] Complete all ID3 tags
- [ ] Accurate BPM (±0.1 precision)
- [ ] Correct key (Camelot notation)
- [ ] Consistent filename
- [ ] Clean source (no YouTube rips)
- [ ] Placed in appropriate folder

---

## 6. Library Management in Mixxx

### Import Process

1. **First launch:** Mixxx prompts for music directory
   - Point to `~/0_library/03_MainLibrary`

2. **Add directories:** Preferences → Library → Add/remove music directories
   - Can add multiple root folders
   - Recursive scanning enabled by default

3. **Rescan options:**
   - Manual: Library → Rescan Library
   - Auto: Enable "Rescan on startup" in Preferences

### Mixxx Library Views

**Tracks:** Master list with multi-column sorting (up to 3 columns)
- Sort by BPM, key, genre, rating, play count
- Circle-of-fifths key sorting available

**Playlists:** Ordered track sequences
- Export formats: M3U, M3U8, PLS, CSV, TXT
- Not directly loadable to decks (use Auto DJ or queue)

**Crates:** Unordered collections (like tags)
- No duplicates allowed
- Perfect for: genres, favorites, party prep, mood

**History:** Automatic session tracking
- Named by date (e.g., "2026-04-08")
- Can rename, lock, merge, export
- Great for set recall and analytics

**Computer:** Access any folder via drag-and-drop
- Quick Links for bookmarked folders
- Not limited to library directories

### Analysis Settings

**Preferences → Beat Detection:**

```
BPM Range: [Set for your genre, e.g., 120-150 for house]
✓ Analyze first beat
✓ Analyze downbeat
✓ Detect key (use Mixed In Key algorithm)
✓ ReplayGain normalization
```

**Batch Analysis:**
1. Go to **Analyze** view
2. Filter: "New" tracks or select all
3. Click "Analyze" - runs in background
4. **Pro tip:** Run analysis before gigs, not during

### Metadata Synchronization

**Critical:** By default, Mixxx stores metadata ONLY in its SQLite database:
- Location: `~/.local/share/Mixxx/2.4/mixxxdb.sqlite` (Linux)
- Location: `~/Library/Application Support/Mixxx/2.4/mixxxdb.sqlite` (macOS)

**To sync changes back to file tags:**
- Preferences → Library → ✓ **Track Metadata Synchronization**
- Or manually: File → Export → Export metadata to file tags

### Managing Missing Files

When moving/renaming files:
1. Preferences → Library → **Relink**
2. Point to old location, then new location
3. Mixxx re-establishes paths without losing cues/beatgrids

**⚠️ NEVER delete and re-import** - you'll lose all cues, loops, ratings!

### Waveform Cache

- Stored separately in `~/.mixxx/waveforms/` (Linux) or corresponding macOS path
- Can be cleared independently if corrupted
- SSD storage recommended for performance

---

## 7. DDJ-FLX4 Controller Configuration

### Current Support Status

**✅ FULL SUPPORT** in Mixxx 2.5.6+ (2.6 recommended)

The DDJ-FLX4 mapping is mature, actively maintained, and includes:
- All deck controls
- Full pad modes (Hot Cue, Beat Loop, Beat Jump, Sampler, Key Shift, Stems)
- BeatFX section
- Mixer controls
- Browse knob

### Setup on Your Systems

**NixOS (nemesis):**
- Udev rules automatically installed via Mixxx package
- No additional configuration needed
- USB access works as normal user

**macOS (alpha):**
- Plug-and-play via USB
- No drivers needed (standard USB MIDI)

### Audio Configuration

```
Preferences → Sound:
├─ Audio Interface: Pioneer DJ DDJ-FLX4
├─ Output 1 (Master): Channels 1-2
├─ Output 2 (Headphones): Channels 3-4
├─ Sample Rate: 44100 Hz
└─ Buffer Size: 256 samples (adjust for latency/stability)
```

### Key Mapping Features

**Deck Controls (per deck):**
- **Play/Pause:** Play/pause button
- **Cue:** Set/recall cue point, back cue
- **Shift+Cue:** Jump to track start and pause
- **Jog Wheel:**
  - Vinyl mode ON: scratching
  - Vinyl mode OFF: pitch bend
  - Shift+Jog: fast search
- **Tempo Slider:** High-resolution pitch (14-bit)
- **Sync:**
  - Short press: Beat sync
  - Long press: Set as master
  - Shift+Sync: Cycle tempo range (6%/10%/16%/25%)

**Pad Modes (8 pads per deck):**

1. **HOT CUE** (default): Pads 1-6 = hot cues 1-6
2. **BEAT LOOP:** 1/2, 1, 2, 4, 8, 16, 32, 64-beat loops
3. **BEAT JUMP:** ±1, ±2, ±4, ±8 beats
4. **SAMPLER:** Trigger sampler slots 1-8
5. **KEY SHIFT:** Transpose ±6 semitones (Mixxx 2.6+)
6. **KEYBOARD (Stems):** Mute/unmute stems 1-4

**Mixer Section:**
- Channel fader, TRIM gain, 3-band EQ (HI/MID/LOW)
- Filter (high-pass/low-pass)
- Crossfader, Cue (PFL), Headphone mix
- BeatFX with Level, Select, On/Off

### Known Issues

**Raspberry Pi USB detection** (Issue #16201):
- May require replug or udev rule
- Not applicable to your setup (nemesis is x86_64, alpha is aarch64)

**All other features fully functional** as of Mixxx 2.5.6+

### Test Your Setup

1. Load track to Deck 1 (Load button)
2. Press Play - audio through Master (channels 1-2)
3. Press Cue - jumps to downbeat and pauses
4. Turn jog wheel - controls pitch/scratch
5. Press headphones Cue - hear in headphones (channels 3-4)
6. Adjust fader, EQ, crossfader - monitor changes

---

## 8. Cross-Device Synchronization

### Your Setup Overview

- **nemesis:** `~/0_library` (NixOS, x86_64-linux)
- **alpha:** `~/0_library` (macOS, aarch64-darwin)
- **Mixxx config paths differ:**
  - Linux: `~/.local/share/Mixxx/2.4/`
  - macOS: `~/Library/Application Support/Mixxx/2.4/`

### ⚠️ Critical: Do NOT Sync Mixxx Database Directly

Mixxx uses SQLite databases that are **NOT safe** for concurrent sync:

```
Files to EXCLUDE from sync:
- mixxxdb.sqlite
- mixxxdb.64.sqlite
- *.sqlite-shm (shared memory)
- *.sqlite-wal (write-ahead log)
```

Syncing these will corrupt your library!

### Recommended Architecture

```
┌─────────────────┐
│  Master Device  │ ← Primary editing (e.g., nemesis studio)
│    (nemesis)    │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│ Laptop  │ │ Backup  │ ← Performance/practice (alpha)
└─────────┘ └─────────┘
```

### Option 1: Syncthing (Recommended)

**Best for:** Real-time, encrypted, decentralized sync

#### NixOS Configuration (nemesis.nix)

Add to your configuration:

```nix
services.syncthing = {
  enable = true;
  openDefaultPorts = true;
  dataDir = "/home/rafiq/.local/state/syncthing";
  configDir = "/home/rafiq/.config/syncthing";
  user = "rafiq";
  group = "users";

  settings = {
    devices = {
      "alpha" = { id = "MACOS-DEVICE-ID"; };
    };

    folders = {
      "music-library" = {
        id = "music-lib";
        path = "/home/rafiq/0_library";
        devices = [ "alpha" ];
        type = "sendreceive";
        fsWatcher = {
          enable = true;
          delayS = 10;
        };
        versioning = {
          type = "staggered";
          params = {
            cleanInterval = "3600";
            maxAge = "2592000"; # 30 days
          };
        };
        ignorePatterns = ''
          **/mixxxdb*.sqlite*
          **/*.sqlite-shm
          **/*.sqlite-wal
          **/*.tmp
        '';
      };

      "mixxx-playlists" = {
        id = "mixxx-playlists";
        path = "/home/rafiq/0_library/05_Playlists";
        devices = [ "alpha" ];
        type = "sendreceive";
        fsWatcher.enable = true;
      };
    };
  };
};
```

#### macOS Configuration (alpha.nix)

```nix
homebrew.casks = [ "syncthing" ];

# Or configure via launchd for more control
launchd.agents.syncthing = {
  enable = true;
  config = {
    ProgramArguments = [
      "/opt/homebrew/bin/syncthing"
      "-serve"
    ];
    RunAtLoad = true;
    KeepAlive = true;
  };
};
```

#### Syncthing Best Practices

1. **Set one device as "send only"** for music if one is master:
   - Folder settings → Advanced → Folder Type: "Send Only"

2. **Enable file versioning** to recover from accidental deletions

3. **Use ignore patterns** for database files (critical!)

4. **Configure pull order:** "Smallest first" for faster initial sync

5. **Use relay servers** if behind NAT (enabled by default)

### Option 2: Resilio Sync (Alternative)

**Best for:** Large libraries, faster initial sync

```json
// ~/.config/resilio-sync/config.json
{
  "listening_port": 55555,
  "storage_path": "/home/rafiq/.local/state/resilio-sync",
  "sync_folders": [
    {
      "secret": "YOUR-READ-WRITE-SECRET",
      "dir": "/home/rafiq/0_library",
      "device_name": "nemesis",
      "save_path": "/home/rafiq/0_library"
    }
  ]
}
```

**Pros:** Faster algorithm, selective sync with placeholders
**Cons:** Closed source, requires account for discovery

### Option 3: rsync (Scheduled/Sync-on-Demand)

**Best for:** Full control, scripting, initial seeding

#### Justfile Commands

Add to your `Justfile`:

```just
# Music library management
dj-sync-push:
  # Push music library to all devices
  rsync -av --delete \
    --exclude='*.sqlite*' \
    --exclude='*.tmp' \
    ~/0_library/ alpha:~/0_library/

dj-sync-pull:
  # Pull latest from master
  rsync -av --delete \
    alpha:~/0_library/ ~/0_library/

dj-export-playlists:
  # Export Mixxx playlists for sync
  @echo "Export playlists from Mixxx GUI to ~/0_library/05_Playlists/"

dj-backup:
  # Full backup of DJ setup
  @mkdir -p ~/backups/dj-$(date +%Y%m%d)
  @rsync -av ~/0_library/ ~/backups/dj-$(date +%Y%m%d)/tracks/
  @rsync -av --exclude='*.sqlite*' \
    ~/.local/share/Mixxx/ ~/backups/dj-$(date +%Y%m%d)/config/
```

#### rsync Script

```bash
#!/usr/bin/env bash
# ~/bin/sync-music.sh

set -euo pipefail

REMOTE="rafiq@alpha.local"
MUSIC_DIR="/home/rafiq/0_library"

# Bidirectional sync
sync_bidirectional() {
  local src="$1"
  local dst="$2"

  # Sync new/changed files both ways
  rsync -av --delete --ignore-existing "$src/" "$dst/"
  rsync -av --delete --ignore-existing "$dst/" "$src/"

  # Then sync modifications (newer wins)
  rsync -av --update "$src/" "$dst/"
  rsync -av --update "$dst/" "$src/"
}

# One-way sync (master -> slave)
sync_to_remote() {
  rsync -av --delete \
    --exclude='*.sqlite*' \
    --exclude='*.sqlite-shm' \
    --exclude='*.sqlite-wal' \
    "$MUSIC_DIR/" "$REMOTE:$MUSIC_DIR/"
}

# Via SSH tunnel
sync_via_ssh() {
  rsync -avz -e "ssh -i ~/.ssh/id_ed25519" \
    --progress \
    "$MUSIC_DIR/" "$REMOTE:$MUSIC_DIR/"
}
```

### Path Differences: Darwin vs Linux

| Purpose | Linux (nemesis) | macOS (alpha) |
|---------|----------------|---------------|
| Home directory | `/home/rafiq` | `/Users/rafiq` |
| Music library | `/home/rafiq/0_library` | `/Users/rafiq/0_library` |
| Mixxx config | `~/.local/share/Mixxx` | `~/Library/Application Support/Mixxx` |
| XDG config | `~/.config` | `~/Library/Application Support` |
| XDG data | `~/.local/share` | `~/Library/Application Support` |
| XDG cache | `~/.local/state` | `~/Library/Caches` |

### Solution: Use Relative Paths in Mixxx

Configure Mixxx to use relative paths:
1. Preferences → Library
2. ✓ **Use relative paths for playlist files**
3. This allows library database to work across different base paths

### Sync Workflow for Your Setup

**Daily (automated via Syncthing):**
- Music files sync bidirectionally
- Playlists sync bidirectionally
- Database files excluded

**Before performances:**
1. Manual sync verification: `just dj-sync-pull`
2. Export current playlists to USB
3. Test USB on DDJ-FLX4

**After library changes:**
1. Allow Syncthing to complete sync
2. Close Mixxx on all devices before major changes
3. Rescan library on device where you made changes

---

## 9. Backup & Redundancy

### The 3-2-1 Rule

- **3 copies** of your library
- **2 different media types**
- **1 offsite backup**

### What to Back Up

**Critical Files:**
1. `~/0_library/` - All music files
2. `~/.local/share/Mixxx/2.4/playlists/` - Playlist exports
3. `~/.mixxx/mixxxdb.sqlite` - Library database (periodic backup only)
4. `~/.mixxx/waveforms/` - Waveform cache (optional)

**Do NOT actively sync:**
- `mixxxdb.sqlite` (corruption risk)
- `*.sqlite-shm`, `*.sqlite-wal` (temporary files)

### Backup Implementation

#### Primary Storage
- Internal SSD or fast external SSD for active library
- Your current setup: nemesis likely has NVMe for primary

#### Local Backup 1
- External HDD (USB 3.0+)
- Use `rsync` daily:
```bash
rsync -avh --delete ~/0_library/ /media/backup/0_library/
```
- Keep connected for quick restores

#### Offsite Backup

**Cloud Options:**
- **Backblaze B2:** Cheap, S3-compatible
- **Google Drive/Dropbox:** Easy but expensive for large libraries
- **Use rclone** for automated sync:

```nix
# NixOS configuration
services.rclone = {
  enable = true;
  config = {
    remote = {
      type = "drive"; # or b2, s3, etc.
      client_id = "YOUR-CLIENT-ID";
      client_secret = "YOUR-CLIENT-SECRET";
      token = "YOUR-TOKEN";
    };
  };
};

# Mount or sync command
systemd.user.services.rclone-sync = {
  Service.ExecStart = ''
    ${pkgs.rclone}/bin/rclone sync /home/rafiq/0_library remote:dj-backup \
      --exclude '*.sqlite*' \
      --transfers 4 \
      --checkers 8
  '';
};
```

**Physical Offsite:**
- External HDD stored at friend's house/safe deposit box
- Rotate monthly

### Performance USB Drives

- 2-3 certified high-speed USB 3.0 drives
- Format as **exFAT** (universal compatibility)
- Duplicate full library on each
- Format regularly, test on target gear

### Backup Schedule

- **Daily:** Incremental sync to local backup (automated)
- **Weekly:** Full backup verification
- **Monthly:** Test restore from backup
- **Quarterly:** Offsite backup refresh
- **Annually:** Replace aging drives (>5 years)

### Recovery Procedure

1. Install Mixxx on new system
2. Copy music files from backup to `~/0_library/`
3. Copy playlist exports to appropriate directory
4. Let Mixxx rescan library (auto on first launch)
5. Import playlists manually
6. Verify all tracks load correctly

---

## 10. Maintenance Workflows

### Weekly Tasks

**Add new music:**
1. Lidarr/Soulseek downloads → `01_Incoming/`
2. Process: tag, rename, move to `02_Processing/`
3. Analyze BPM/key using Mixxx or Kid3
4. Move to `03_MainLibrary/By_Genre/`
5. Add to relevant crates/playlists in Mixxx
6. Rescan library

**Quick library health check:**
- Any tracks marked "missing"? (Fix paths or re-download)
- New playlists organized?
- Backup up to date?

### Monthly Tasks

**Deep library audit:**
- Remove duplicates (use `fdupes` or similar)
- Re-analyze tracks with incorrect BPM
- Clean tracks never played in 6+ months
- Update genre classifications if needed

**Backup verification:**
- Check backup logs
- Test restore of a few random files
- Verify backup drive health

### Quarterly Tasks

**Library optimization:**
- Export important crates/playlists to USB drives
- Test USB drives on actual DDJ-FLX4
- Refresh Lidarr/Soulseek subscriptions if applicable

**System maintenance:**
- Update Mixxx via NixOS: `nh os switch` or `nh darwin switch`
- Check for controller mapping updates
- Review Syncthing sync logs

### Annual Tasks

**Complete library review:**
- Identify dead weight (low-rated, never played)
- Move to `04_Archive/` or delete
- Consider re-downloading in higher quality

**Infrastructure:**
- Replace aging backup drives (>5 years old)
- Upgrade storage capacity if needed
- Document any changes to folder structure or workflow

---

## Quick Start Checklist

### Day 1: Setup

- [ ] Install Mixxx (already configured in your flake)
- [ ] Connect and test DDJ-FLX4
- [ ] Create folder structure: `mkdir -p ~/0_library/{01_Incoming,02_Processing,03_MainLibrary,04_Archive,05_Playlists}`
- [ ] Set music directory in Mixxx Preferences
- [ ] Configure audio interface (DDJ-FLX4, channels 1-2/3-4)

### Week 1: Initial Library

- [ ] Install Nicotine+: `nix shell nixpkgs#nicotine-plus`
- [ ] Set up Lidarr (Docker or native)
- [ ] Download/collect initial 100-200 tracks (lossless preferred)
- [ ] Tag all files with complete metadata (use Kid3)
- [ ] Move to organized folders
- [ ] Let Mixxx analyze (overnight)
- [ ] Create initial crates: "Favorites", "Upcoming Gigs", "Opener", "Peak Time", "Midnight"

### Ongoing

- [ ] Add 5-10 tracks weekly (automated via Lidarr + manual)
- [ ] Maintain backups (automated)
- [ ] Export playlists to USB before gigs
- [ ] Keep Mixxx updated via NixOS

---

## Additional Configuration for Your Flake

### Add to `rafiq.nix` (home-manager section)

```nix
home.packages =
  (lib.lists.optional pkgs.stdenv.isDarwin pkgs.mixxx)
  ++ (lib.lists.optional pkgs.stdenv.isLinux pkgs.mixxx)
  ++ [
    pkgs.kid3          # Tag editor
    pkgs.rclone        # Cloud sync
    pkgs.fd            # Duplicate finder
  ]
  ++ lib.lists.optional pkgs.stdenv.isLinux [
    pkgs.nicotine-plus # Soulseek client (Linux)
  ];

# Syncthing configuration
services.syncthing = {
  enable = pkgs.stdenv.isLinux; # Or enable on both
  settings.folders = {
    "music-library" = {
      id = "music-lib";
      path = config.home.homeDirectory + "/0_library";
      type = "sendreceive";
      fsWatcher.enable = true;
      versioning = {
        type = "staggered";
        params.maxAge = "2592000"; # 30 days
      };
      ignorePatterns = ''
        **/mixxxdb*.sqlite*
        **/*.sqlite-shm
        **/*.sqlite-wal
      '';
    };
  };
};
```

### Add to `Justfile`

```just
# DJ library management
dj-sync-push:
  rsync -av --delete \
    --exclude='*.sqlite*' \
    ~/0_library/ alpha:~/0_library/

dj-sync-pull:
  rsync -av --delete \
    alpha:~/0_library/ ~/0_library/

dj-export-playlists:
  @echo "Export playlists from Mixxx GUI to ~/0_library/05_Playlists/"

dj-backup:
  @mkdir -p ~/backups/dj-$(date +%Y%m%d)
  @rsync -av ~/0_library/ ~/backups/dj-$(date +%Y%m%d)/tracks/
  @rsync -av --exclude='*.sqlite*' \
    ~/.local/share/Mixxx/ ~/backups/dj-$(date +%Y%m%d)/config/

dj-analyze:
  @echo "Run Mixxx analysis on new tracks"
  @mixxx --rescan
```

---

## Resources

**Mixxx:**
- Manual: https://manual.mixxx.org/
- DDJ-FLX4 mapping: Included in Mixxx 2.5.6+
- Zulip chat: https://mixxx.zulipchat.com

**Lidarr:**
- Official: https://lidarr.audio
- Wiki: https://wiki.servarr.com/lidarr
- Docker: lscr.io/linuxserver/lidarr:latest

**Soulseek/Nicotine+:**
- Nicotine+: https://nicotine-plus.org/
- GitHub: https://github.com/nicotine-plus/nicotine-plus
- Soulseek: https://www.slsknet.org/

**Sync Tools:**
- Syncthing: https://syncthing.net/
- Resilio: https://www.resilio.com/
- rclone: https://rclone.org/

---

**Final Note:** This setup gives you a professional, automated, and redundant DJ library management system that works seamlessly across your NixOS and macOS devices. The combination of Lidarr (automation), Soulseek (discovery), manual curation (quality control), and Syncthing (sync) provides a comprehensive solution while respecting legal considerations 😉

Happy DJing! 🎧