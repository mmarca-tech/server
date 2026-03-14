#!/usr/bin/env python3

"""
Movie Organization Script - Restructures /srv/media/movies for Radarr
Converts from messy naming to: /movies/Title (YYYY)/
"""

import os
import shutil
import re
import json
from pathlib import Path
from datetime import datetime

SOURCE_DIR = "/srv/media/movies"
TARGET_DIR = "/srv/media/movies-new"
LOG_FILE = "/tmp/movie_organization.log"

def extract_title_and_year(folder_name):
    """Extract clean title and year from messy folder name"""
    
    # Remove common quality indicators
    clean = re.sub(r'\[(.*?)\]|\{(.*?)\}|(?:BluRay|DVDRip|XviD|H\.?264|x265|HEVC|1080p|720p|480p|BRRIP|DVDRIP)[^a-zA-Z]*', ' ', folder_name)
    clean = re.sub(r'(?:BRRip|XviD|AC3|AAC|DTS|FLAC|MP3).*', '', clean)
    
    # Extract year - try various patterns
    year_match = re.search(r'\((\d{4})\)|\[(\d{4})\](?!\w)|(?<!\d)(\d{4})(?![_\w])', clean)
    year = None
    if year_match:
        year = year_match.group(1) or year_match.group(2) or year_match.group(3)
        clean = clean[:year_match.start()].strip()
    
    # Remove common separators and clean up
    clean = re.sub(r'\s*[-_]\s*', ' ', clean)
    clean = re.sub(r'\s{2,}', ' ', clean).strip()
    
    # Handle director names (Wim Wenders - Title format)
    if ' - ' in clean:
        parts = clean.split(' - ')
        # If first part looks like a name, skip it
        if len(parts) > 1 and len(parts[0].split()) <= 2:
            clean = ' - '.join(parts[1:])
    
    # Remove trailing underscores
    clean = clean.rstrip('_').strip()
    
    return clean, year

def get_video_files(folder_path):
    """Get all video files in a folder"""
    video_exts = {'.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.webm', '.m4v'}
    return [f for f in os.listdir(folder_path) if os.path.splitext(f)[1].lower() in video_exts]

def copy_movie_folder(source_path, title, year, log):
    """Copy movie folder to new structure"""
    
    # Create folder name
    if year:
        folder_name = f"{title} ({year})"
    else:
        folder_name = title
    
    target_path = os.path.join(TARGET_DIR, folder_name)
    
    # Handle duplicates
    counter = 1
    base_path = target_path
    while os.path.exists(target_path):
        if year:
            target_path = f"{base_path[:-len(year)-1]}_{counter} ({year})"
        else:
            target_path = f"{base_path}_{counter}"
        counter += 1
    
    try:
        # Create directory
        os.makedirs(target_path, exist_ok=True)
        
        # Move video files and subtitles (faster than copy)
        for item in os.listdir(source_path):
            src_item = os.path.join(source_path, item)
            dst_item = os.path.join(target_path, item)
            
            # Move videos and subtitle files
            if os.path.isfile(src_item):
                ext = os.path.splitext(item)[1].lower()
                if ext in {'.mkv', '.mp4', '.avi', '.mov', '.flv', '.wmv', '.webm', '.m4v',
                          '.srt', '.ass', '.ssa', '.sub', '.vtt', '.lrc'}:
                    try:
                        print(f"  Moving: {item[:50]}...", flush=True)
                        shutil.move(src_item, dst_item)
                    except Exception as e:
                        log["errors"].append(f"{folder_name}/{item}: {str(e)}")
                        # Continue on move errors instead of failing entire folder
        
        log["success"] += 1
        return True, None
        
    except Exception as e:
        log["errors"].append(f"{os.path.basename(source_path)}: {str(e)}")
        return False, str(e)

def main():
    print(f"🎬 Movie Organization Script")
    print(f"Source: {SOURCE_DIR}")
    print(f"Target: {TARGET_DIR}")
    print("=" * 60)
    
    # Verify source exists
    if not os.path.isdir(SOURCE_DIR):
        print(f"❌ Source directory not found: {SOURCE_DIR}")
        return
    
    # Create target directory
    os.makedirs(TARGET_DIR, exist_ok=True)
    
    # Initialize log
    log = {
        "timestamp": datetime.now().isoformat(),
        "total": 0,
        "success": 0,
        "errors": [],
        "skipped": 0,
        "movies": []
    }
    
    # Process all movie folders
    movie_folders = [f for f in os.listdir(SOURCE_DIR) 
                     if os.path.isdir(os.path.join(SOURCE_DIR, f))]
    
    print(f"Found {len(movie_folders)} movie folders")
    
    for i, folder in enumerate(sorted(movie_folders), 1):
        source_path = os.path.join(SOURCE_DIR, folder)
        
        # Skip if no video files
        if not get_video_files(source_path):
            log["skipped"] += 1
            continue
        
        log["total"] += 1
        
        # Extract title and year
        title, year = extract_title_and_year(folder)
        
        if not title:
            title = folder
        
        # Show progress
        print(f"[{i}/{len(movie_folders)}] Processing: {title}...", flush=True)
        
        # Copy to new structure
        success, error = copy_movie_folder(source_path, title, year, log)
        
        # Log entry
        movie_entry = {
            "original": folder,
            "clean_title": title,
            "year": year,
            "success": success
        }
        if error:
            movie_entry["error"] = error
        log["movies"].append(movie_entry)
        
        if i % 10 == 0:
            print(f"  ✓ Completed {i}/{len(movie_folders)} folders\n", flush=True)
    
    # Write log
    with open(LOG_FILE, 'w') as f:
        json.dump(log, f, indent=2)
    
    print("\n" + "=" * 60)
    print(f"✓ Processed: {log['success']}/{log['total']}")
    print(f"✗ Errors: {len(log['errors'])}")
    print(f"⊘ Skipped (no videos): {log['skipped']}")
    print(f"📋 Log saved to: {LOG_FILE}")
    
    if log["errors"]:
        print("\nErrors:")
        for error in log["errors"][:10]:
            print(f"  - {error}")

if __name__ == "__main__":
    main()
