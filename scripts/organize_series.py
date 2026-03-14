#!/usr/bin/env python3

"""
Series Organization Script - Restructures /srv/media/series for Sonarr
Creates: /tv/Series Name/Season XX/Series Name - SxxExx - Title.mkv format
"""

import os
import shutil
import re
import json
from pathlib import Path
from datetime import datetime

SOURCE_DIR = "/srv/media/series"
TARGET_DIR = "/srv/media/tv"
LOG_FILE = "/tmp/series_organization.log"

def extract_series_name(folder_name):
    """Extract clean series name from folder"""
    # Remove brackets and quality info
    clean = re.sub(r'\[[^\]]*\]|\{[^\}]*\}', '', folder_name)
    clean = re.sub(r'(?:BluRay|DVDRip|XviD|H\.?264|x265|720p|1080p|BD|dual|audio|eng|jap|sub)', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'\((?:001|S\d{2})[^)]*\)', '', clean)  # Remove episode ranges
    clean = re.sub(r'[_-]\s*(?:complete|series|movies|dual|audio).*', '', clean, flags=re.IGNORECASE)
    clean = re.sub(r'\s{2,}', ' ', clean).strip('_- ')
    return clean

def extract_episode_info(filename):
    """Extract season and episode numbers from filename"""
    # Try various patterns: SxxExx, s##e##, 01x05, etc.
    patterns = [
        r'[Ss](\d{1,2})[Ee](\d{1,2})',  # S01E05
        r'(\d{1,2})x(\d{1,2})',          # 01x05
        r'(?:season|ep)\s*(\d{1,2})\D+(\d{1,2})',  # season 1 ep 5
    ]
    
    for pattern in patterns:
        match = re.search(pattern, filename)
        if match:
            season = int(match.group(1))
            episode = int(match.group(2))
            return season, episode
    
    return None, None

def process_flat_episodes(source_path, series_name, target_path):
    """Handle flat episode structure (no Season folders)"""
    episodes = {}
    
    for file in os.listdir(source_path):
        if not os.path.isfile(os.path.join(source_path, file)):
            continue
        
        ext = os.path.splitext(file)[1].lower()
        if ext not in {'.mkv', '.mp4', '.avi', '.mov'}:
            continue
        
        season, episode = extract_episode_info(file)
        if season is not None and episode is not None:
            if season not in episodes:
                episodes[season] = []
            episodes[season].append(file)
    
    # Create season folders and copy files
    for season in sorted(episodes.keys()):
        season_dir = os.path.join(target_path, f"Season {season:02d}")
        os.makedirs(season_dir, exist_ok=True)
        
        for episode_file in sorted(episodes[season]):
            src = os.path.join(source_path, episode_file)
            dst = os.path.join(season_dir, episode_file)
            
            # Rename to standard format if possible
            season_num, episode_num = extract_episode_info(episode_file)
            if season_num and episode_num:
                new_name = f"{series_name} - S{season_num:02d}E{episode_num:02d} - {episode_file}"
                dst = os.path.join(season_dir, new_name)
            
            try:
                shutil.move(src, dst)
            except Exception as e:
                # Log but continue on move errors
                print(f"    ⚠ Failed to move {episode_file}: {e}", flush=True)
    
    return len(episodes) > 0

def process_season_folders(source_path, series_name, target_path):
    """Handle already-organized Season folders"""
    has_seasons = False
    
    for item in os.listdir(source_path):
        item_path = os.path.join(source_path, item)
        
        # Check if it's a season folder
        season_match = re.search(r'[Ss]eason\s+(\d+)', item, re.IGNORECASE)
        if season_match and os.path.isdir(item_path):
            has_seasons = True
            season_num = int(season_match.group(1))
            season_dir = os.path.join(target_path, f"Season {season_num:02d}")
            os.makedirs(season_dir, exist_ok=True)
            
            # Move video files
            for file in os.listdir(item_path):
                src_file = os.path.join(item_path, file)
                if os.path.isfile(src_file):
                    ext = os.path.splitext(file)[1].lower()
                    if ext in {'.mkv', '.mp4', '.avi', '.mov'}:
                        dst_file = os.path.join(season_dir, file)
                        try:
                            shutil.move(src_file, dst_file)
                        except Exception as e:
                            # Log but continue on move errors
                            print(f"    ⚠ Failed to move {file}: {e}", flush=True)
    
    return has_seasons

def organize_series(source_path, series_name, log):
    """Organize a single series"""
    
    # Create target directory
    target_path = os.path.join(TARGET_DIR, series_name)
    
    # Handle duplicates
    counter = 1
    base_path = target_path
    while os.path.exists(target_path):
        target_path = f"{base_path}_{counter}"
        counter += 1
    
    try:
        os.makedirs(target_path, exist_ok=True)
        
        # Try season folders first, then flat structure
        if not process_season_folders(source_path, series_name, target_path):
            process_flat_episodes(source_path, series_name, target_path)
        
        log["success"] += 1
        return True, None
        
    except Exception as e:
        log["errors"].append(f"{os.path.basename(source_path)}: {str(e)}")
        return False, str(e)

def main():
    print(f"📺 Series Organization Script")
    print(f"Source: {SOURCE_DIR}")
    print(f"Target: {TARGET_DIR}")
    print("=" * 60)
    
    if not os.path.isdir(SOURCE_DIR):
        print(f"❌ Source directory not found: {SOURCE_DIR}")
        return
    
    os.makedirs(TARGET_DIR, exist_ok=True)
    
    log = {
        "timestamp": datetime.now().isoformat(),
        "total": 0,
        "success": 0,
        "errors": [],
        "series": []
    }
    
    # Process all series folders
    series_folders = [f for f in os.listdir(SOURCE_DIR) 
                      if os.path.isdir(os.path.join(SOURCE_DIR, f))]
    
    print(f"Found {len(series_folders)} series folders")
    
    for i, folder in enumerate(sorted(series_folders), 1):
        source_path = os.path.join(SOURCE_DIR, folder)
        
        log["total"] += 1
        
        # Extract series name
        series_name = extract_series_name(folder)
        if not series_name:
            series_name = folder
        
        # Organize series
        success, error = organize_series(source_path, series_name, log)
        
        series_entry = {
            "original": folder,
            "clean_name": series_name,
            "success": success
        }
        if error:
            series_entry["error"] = error
        log["series"].append(series_entry)
        
        print(f"  [{i}/{len(series_folders)}] {series_name}")
    
    # Write log
    with open(LOG_FILE, 'w') as f:
        json.dump(log, f, indent=2)
    
    print("\n" + "=" * 60)
    print(f"✓ Processed: {log['success']}/{log['total']}")
    print(f"✗ Errors: {len(log['errors'])}")
    print(f"📋 Log saved to: {LOG_FILE}")

if __name__ == "__main__":
    main()
