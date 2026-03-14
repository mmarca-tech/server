#!/usr/bin/env python3

"""
Verification Script - Check organization quality and container access
"""

import os
import json
import subprocess
import re

def verify_movie_structure():
    """Verify /srv/media/movies-new structure"""
    print("\n📽️  MOVIE STRUCTURE VERIFICATION")
    print("=" * 60)
    
    if not os.path.exists("/srv/media/movies-new"):
        print("❌ /srv/media/movies-new does not exist")
        return 0, 0
    
    movies = [d for d in os.listdir("/srv/media/movies-new") 
              if os.path.isdir(os.path.join("/srv/media/movies-new", d))]
    
    valid = 0
    for movie_dir in sorted(movies)[:10]:  # Show first 10
        print(f"  • {movie_dir}")
        valid += 1
    
    if len(movies) > 10:
        print(f"  ... and {len(movies) - 10} more")
    
    print(f"\nTotal: {len(movies)} movies organized")
    return len(movies), len(movies)

def verify_series_structure():
    """Verify /srv/media/tv structure"""
    print("\n📺 SERIES STRUCTURE VERIFICATION")
    print("=" * 60)
    
    if not os.path.exists("/srv/media/tv"):
        print("❌ /srv/media/tv does not exist")
        return 0, 0
    
    series = [d for d in os.listdir("/srv/media/tv") 
              if os.path.isdir(os.path.join("/srv/media/tv", d))]
    
    for series_name in sorted(series):
        season_count = len([d for d in os.listdir(f"/srv/media/tv/{series_name}") 
                           if os.path.isdir(f"/srv/media/tv/{series_name}/{d}")])
        print(f"  • {series_name} ({season_count} seasons)")
    
    print(f"\nTotal: {len(series)} series organized")
    return len(series), len(series)

def verify_container_access():
    """Test docker container access"""
    print("\n🐳 CONTAINER ACCESS VERIFICATION")
    print("=" * 60)
    
    containers = ["radarr", "sonarr", "jellyfin_fresh-jellyfin-1"]
    results = {}
    
    for container in containers:
        try:
            result = subprocess.run(
                ["docker", "exec", container, "test", "-d", "/media"],
                capture_output=True, timeout=5
            )
            if result.returncode == 0:
                results[container] = "✓"
                print(f"  ✓ {container}: /media accessible")
            else:
                results[container] = "✗"
                print(f"  ✗ {container}: Cannot access /media")
        except Exception as e:
            results[container] = "✗"
            print(f"  ✗ {container}: {str(e)[:50]}")
    
    return results

def check_permissions():
    """Check directory permissions"""
    print("\n🔐 PERMISSION VERIFICATION")
    print("=" * 60)
    
    paths = ["/srv/media", "/srv/media/movies-new", "/srv/media/tv"]
    
    for path in paths:
        if os.path.exists(path):
            stat_info = os.stat(path)
            perms = oct(stat_info.st_mode)[-3:]
            owner_uid = stat_info.st_uid
            owner_gid = stat_info.st_gid
            print(f"  {path}")
            print(f"    Permissions: {perms}")
            print(f"    Owner: {owner_uid}:{owner_gid}")

def main():
    print("\n🔍 MEDIA ORGANIZATION VERIFICATION")
    print("=" * 60)
    
    movies, movies_expected = verify_movie_structure()
    series, series_expected = verify_series_structure()
    containers = verify_container_access()
    check_permissions()
    
    print("\n" + "=" * 60)
    print("📋 VERIFICATION SUMMARY")
    print(f"  Movies: {movies} organized")
    print(f"  Series: {series} organized")
    print(f"  Container access: {sum(1 for v in containers.values() if v == '✓')}/{len(containers)}")
    
    if movies > 0 and series > 0:
        print("\n✓ Structure ready for migration")
    else:
        print("\n⚠️  Organization may not be complete")

if __name__ == "__main__":
    main()
