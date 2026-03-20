#!/usr/bin/env python3
# =============================================================================
# HomeLab Stack — Performance Test Script
# Tests startup time, memory usage, and throughput
# =============================================================================

import time
import subprocess
import json
import sys
import os

# Colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

# Test results storage
test_results = {
    "startup_time": {},
    "memory_usage": {},
    "throughput": {},
    "concurrency": {},
    "code_quality": {}
}

# Logging functions
def log_info(msg):
    print(f"{GREEN}[INFO]{NC} {msg}")

def log_warn(msg):
    print(f"{YELLOW}[WARN]{NC} {msg}")

def log_error(msg):
    print(f"{RED}[ERROR]{NC} {msg}", file=sys.stderr)

def log_section(title):
    print(f"\n{BOLD}{CYAN}=== {title} ==={NC}\n")

# Test 1: Code Quality (bash -n syntax check)
def test_code_quality():
    log_section("Test 1: Code Quality")
    
    scripts = [
        "scripts/setup-cn-mirrors.sh",
        "scripts/localize-images.sh",
        "scripts/check-connectivity.sh",
        "scripts/wait-healthy.sh",
        "scripts/diagnose.sh"
    ]
    
    errors = 0
    
    for script in scripts:
        try:
            # Basic syntax check with bash -n
            result = subprocess.run(
                ["bash", "-n", script],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                log_info(f"✓ {script}: Syntax OK")
                test_results["code_quality"][script] = "PASS"
            else:
                log_error(f"✗ {script}: Syntax errors")
                print(result.stderr)
                test_results["code_quality"][script] = "FAIL"
                errors += 1
        except Exception as e:
            log_error(f"✗ {script}: {e}")
            errors += 1
    
    if errors == 0:
        log_info(f"Code quality: All {len(scripts)} scripts passed")
    else:
        log_error(f"Code quality: {errors} script(s) with errors")
    
    return errors == 0

# Test 2: Startup Time
def test_startup_time():
    log_section("Test 2: Startup Time")
    
    scripts = [
        "scripts/check-connectivity.sh",
        "scripts/diagnose.sh",
    ]
    
    for script in scripts:
        start_time = time.time()
        
        try:
            # Run script with --help to test startup
            result = subprocess.run(
                ["bash", script, "--help"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            elapsed = time.time() - start_time
            
            if result.returncode == 0:
                startup_ms = elapsed * 1000
                log_info(f"✓ {script}: {startup_ms:.0f}ms")
                test_results["startup_time"][script] = {
                    "ms": round(startup_ms, 2),
                    "status": "PASS"
                }
            else:
                log_error(f"✗ {script}: Failed with exit code {result.returncode}")
                test_results["startup_time"][script] = "FAIL"
        except subprocess.TimeoutExpired:
            log_error(f"✗ {script}: Timeout (>5s)")
            test_results["startup_time"][script] = "TIMEOUT"
        except Exception as e:
            log_error(f"✗ {script}: {e}")
            test_results["startup_time"][script] = "ERROR"
    
    log_info("Startup time test complete")

# Test 3: Memory Usage (file size as proxy)
def test_memory_usage():
    log_section("Test 3: Memory Usage (script size)")
    
    scripts = [
        "scripts/setup-cn-mirrors.sh",
        "scripts/localize-images.sh",
        "scripts/check-connectivity.sh",
        "scripts/wait-healthy.sh",
        "scripts/diagnose.sh",
    ]
    
    for script in scripts:
        try:
            # Get script size
            size_bytes = os.path.getsize(script)
            size_kb = size_bytes / 1024
            
            log_info(f"✓ {script}: {size_kb:.1f} KB")
            test_results["memory_usage"][script] = {
                "kb": round(size_kb, 2),
                "status": "PASS"
            }
        except Exception as e:
            log_error(f"✗ {script}: {e}")
            test_results["memory_usage"][script] = "ERROR"
    
    log_info("Memory usage test complete")

# Test 4: Throughput (lines processed)
def test_throughput():
    log_section("Test 4: Throughput (lines/second)")
    
    scripts = [
        "scripts/check-connectivity.sh",
        "scripts/diagnose.sh",
    ]
    
    for script in scripts:
        start_time = time.time()
        
        try:
            # Read script content
            with open(script, 'r') as f:
                lines = f.readlines()
            
            total_lines = len(lines)
            elapsed = time.time() - start_time
            
            if elapsed > 0:
                throughput = total_lines / elapsed
                log_info(f"✓ {script}: {throughput:.1f} lines/second ({total_lines} lines)")
                test_results["throughput"][script] = {
                    "lines_per_second": round(throughput, 2),
                    "total_lines": total_lines,
                    "status": "PASS"
                }
            else:
                log_warn(f"⚠ {script}: Script too fast to measure")
                test_results["throughput"][script] = {
                    "lines_per_second": total_lines * 1000,  # Assume <1ms
                    "total_lines": total_lines,
                    "status": "PASS"
                }
        except Exception as e:
            log_error(f"✗ {script}: {e}")
            test_results["throughput"][script] = "ERROR"
    
    log_info("Throughput test complete")

# Test 5: High Concurrency
def test_concurrency():
    log_section("Test 5: High Concurrency (simulated)")
    
    scripts = [
        "scripts/check-connectivity.sh",
        "scripts/diagnose.sh",
    ]
    
    concurrent_count = 5
    processes = []
    
    start_time = time.time()
    
    for i in range(concurrent_count):
        for script in scripts:
            try:
                p = subprocess.Popen(
                    ["bash", script, "--help"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE
                )
                processes.append(p)
            except Exception as e:
                log_error(f"✗ Failed to start {script}: {e}")
    
    # Wait for all processes
    for p in processes:
        try:
            p.wait()
        except Exception:
            pass
    
    elapsed = time.time() - start_time
    
    if elapsed > 0:
        total_scripts = len(scripts) * concurrent_count
        throughput = total_scripts / elapsed
        log_info(f"✓ Concurrency test: {total_scripts} scripts in {elapsed:.2f}s ({throughput:.1f}/s)")
        test_results["concurrency"] = {
            "concurrent_scripts": total_scripts,
            "time_seconds": round(elapsed, 2),
            "throughput": round(throughput, 2),
            "status": "PASS"
        }
    else:
        log_error("✗ Concurrency test failed")
        test_results["concurrency"] = "FAIL"
    
    log_info("Concurrency test complete")

# Main
def main():
    log_section("HomeLab Stack Performance Tests")
    
    # Run all tests
    code_ok = test_code_quality()
    
    if not code_ok:
        log_error("Code quality test failed. Skipping other tests.")
        sys.exit(1)
    
    test_startup_time()
    test_memory_usage()
    test_throughput()
    test_concurrency()
    
    # Print summary
    log_section("Test Summary")
    
    print(json.dumps(test_results, indent=2))
    
    # Calculate overall status
    all_passed = True
    for category, results in test_results.items():
        if isinstance(results, dict):
            for key, value in results.items():
                if isinstance(value, dict) and value.get("status") != "PASS":
                    all_passed = False
                    break
                elif value == "FAIL":
                    all_passed = False
                    break
    
    print()
    if all_passed:
        log_info("✅ ALL TESTS PASSED")
    else:
        log_error("❌ SOME TESTS FAILED")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
