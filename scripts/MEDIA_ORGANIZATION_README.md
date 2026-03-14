# Media Organization Scripts

## Quick Start

Run the main orchestration script:

```bash
sudo -u manu bash /srv/server/scripts/execute_media_organization.sh
```

## What's Included

### Main Execution
- **execute_media_organization.sh** - Master script that runs all 7 phases:
  1. Permission fixes
  2. Movie organization (256 folders)
  3. Series organization (14 folders)
  4. Verification
  5. Backup & deployment
  6. Container integration
  7. Final report

### Python Modules
- **organize_movies.py** - Reorganizes 256 movies from messy naming to `/srv/media/movies/Title (YYYY)/`
- **organize_series.py** - Reorganizes 14 series from mixed structures to `/srv/media/tv/Series Name/Season XX/`
- **verify_organization.py** - Tests new structure and container access

### Documentation
- **EXECUTION_INSTRUCTIONS.md** - Step-by-step guide with troubleshooting
- **MEDIA_ORGANIZATION_README.md** - This file

## Timeline
- **Total execution:** 5-10 minutes
- Movie processing: ~2-3 minutes
- Series processing: ~1 minute
- Verification: ~30 seconds
- Backup/Deploy: ~1 minute

## Safety
- Original `/srv/media/movies` backed up to `/srv/media/movies-old`
- All operations logged to `/tmp/movie_organization.log` and `/tmp/series_organization.log`
- Easy rollback if needed

## Result

### Before
```
/srv/media/movies/
├── Wim Wenders - The Million Dollar Hotel 2000/
├── The Best Exotic Marigold Hotel[2011]BRRip XviD-ETRG/
└── ... 254 more messy folders ...

/srv/media/series/
├── Babylon Berlin/
├── Band_of_brothers/
└── ... 12 more mixed structures ...
```

### After
```
/srv/media/movies/
├── The Million Dollar Hotel (2000)/
├── The Best Exotic Marigold Hotel (2011)/
└── ... 254 clean folders ...

/srv/media/tv/
├── Babylon Berlin/Season 01/
│   ├── Babylon Berlin - S01E01 - Title.mkv
│   └── ...
├── Band of Brothers/Season 01/
│   └── ...
└── ... 12 organized series ...

/srv/media/movies-old/
└── (backup of original movies folder)
```

## Command Reference

### Execute everything at once
```bash
sudo -u manu bash /srv/server/scripts/execute_media_organization.sh
```

### Run individual phases
```bash
# Just movies
python3 /srv/server/scripts/organize_movies.py

# Just series
python3 /srv/server/scripts/organize_series.py

# Just verification
python3 /srv/server/scripts/verify_organization.py
```

### Check logs
```bash
cat /tmp/movie_organization.log | jq
cat /tmp/series_organization.log | jq
```

### Rollback if needed
```bash
rm -rf /srv/media/movies
mv /srv/media/movies-old /srv/media/movies
```

## Container Integration After Execution

### Radarr
1. Settings → Media Management → Movie Paths
2. Add: `/media/movies`

### Sonarr
1. Settings → Media Management → TV Paths
2. Add: `/media/tv`

### Jellyfin
1. Dashboard → Libraries
2. Add Movies Library: `/media/movies`
3. Add Shows Library: `/media/tv`
4. Run "Scan All Libraries"

## Questions?

See detailed documentation:
- `/srv/server/scripts/EXECUTION_INSTRUCTIONS.md` - Full guide with troubleshooting
- `/tmp/movie_organization.log` - Movie organization details
- `/tmp/series_organization.log` - Series organization details
