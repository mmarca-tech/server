# Media Organization - Execution Instructions

## Quick Start (5 minutes)

For proper execution, you need:
- **User:** Run as `manu` user (not `openclaw`)
- **Permissions:** Must have write access to /srv/media
- **Python 3:** Available on the system

### Single Command Execution

```bash
sudo -u manu bash /tmp/execute_media_organization.sh
```

Or if you're already logged in as manu:

```bash
bash /tmp/execute_media_organization.sh
```

## What Gets Organized

### Movies (256 folders)
- **From:** `/srv/media/movies/` with messy names like:
  - `Wim Wenders - The Million Dollar Hotel 2000`
  - `The Best Exotic Marigold Hotel[2011]BRRip XviD-ETRG`
  
- **To:** `/srv/media/movies-new/Title (YYYY)/` structure:
  - `The Million Dollar Hotel (2000)/`
  - `The Best Exotic Marigold Hotel (2011)/`

### Series (14 folders)
- **From:** `/srv/media/series/` with mixed formats
  
- **To:** `/srv/media/tv/Series Name/Season XX/` structure:
  - `Babylon Berlin/Season 01/`
  - `The Office US/Season 01/`

## Process Steps

1. **Permissions Fix** - Ensures manu user can write
2. **Movie Organization** - Parses 256 folders, extracts clean names
3. **Series Organization** - Structures 14 series with proper Season folders
4. **Verification** - Tests container access and file structure
5. **Backup & Deploy** - Moves old structure to `movies-old`, deploys new one
6. **Container Setup** - Instructions for Radarr/Sonarr/Jellyfin integration

## Timeline

- **Movie Processing:** ~2-3 minutes
- **Series Processing:** ~1 minute
- **Verification:** ~30 seconds
- **Backup/Deploy:** ~1 minute
- **Total:** ~5-10 minutes depending on system I/O

## Safety

- **Original data:** Backed up to `/srv/media/movies-old/`
- **Rollback:** Simple `mv` command if something goes wrong
- **Logging:** All operations logged to `/tmp/movie_organization.log` and `/tmp/series_organization.log`

## Troubleshooting

### If Docker containers can't see new structure:

```bash
# Check permissions
docker exec radarr ls -la /media/movies | head

# Check Radarr library path in settings
docker exec radarr curl -s http://localhost:7878/api/v3/config/roots | jq
```

### If movies/series don't appear in Jellyfin:

1. Go to Dashboard → Content Library Settings
2. Verify paths are set to `/media/movies` and `/media/tv`
3. Run "Scan All Libraries"
4. Wait for indexing to complete

### If you need to rollback:

```bash
rm -rf /srv/media/movies
mv /srv/media/movies-old /srv/media/movies
# Optional: rm -rf /srv/media/tv
```

## Files Created

All scripts are in `/tmp/`:

- `execute_media_organization.sh` - Main orchestration script
- `organize_movies.py` - Movie organization logic
- `organize_series.py` - Series organization logic
- `verify_organization.py` - Post-organization verification
- `MEDIA_ORGANIZATION_PLAN.md` - Detailed planning document
- `movie_organization.log` - Generated after movies step
- `series_organization.log` - Generated after series step

## Container Integration After Execution

### Radarr
1. Settings → Media Management → Movie Paths
2. Add: `/media/movies`
3. Verify: GET `http://localhost:7878/api/v3/system/status`

### Sonarr
1. Settings → Media Management → TV Paths
2. Add: `/media/tv`
3. Verify: GET `http://localhost:8989/api/v3/system/status`

### Jellyfin
1. Dashboard → Libraries
2. Add Movies Library: `/media/movies`
3. Add Shows Library: `/media/tv`
4. Scan libraries

## Questions or Issues?

Check the detailed logs:
```bash
cat /tmp/movie_organization.log | jq '.errors'
cat /tmp/series_organization.log | jq '.errors'
```

All errors are captured with file names and detailed descriptions.
