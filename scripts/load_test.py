import time
import requests
import concurrent.futures

URL = "http://localhost:8000/health"
TOTAL_REQUESTS = 100
CONCURRENCY = 10

def make_request(i):
    start = time.time()
    try:
        r = requests.get(URL, timeout=5)
        duration = time.time() - start
        return r.status_code, duration
    except Exception as e:
        return 0, 0

print(f"=== Starting Load Test: {TOTAL_REQUESTS} requests, Concurrency {CONCURRENCY} ===")
start_total = time.time()

with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENCY) as executor:
    results = list(executor.map(make_request, range(TOTAL_REQUESTS)))

total_time = time.time() - start_total
success_count = sum(1 for status, _ in results if status == 200)
durations = [d for _, d in results if d > 0]
avg_time = sum(durations) / len(durations) if durations else 0

print(f"Total Time Taken:     {total_time:.2f} seconds")
print(f"Successful Requests:  {success_count}/{TOTAL_REQUESTS} (200 OK)")
print(f"Requests per Second:  {TOTAL_REQUESTS / total_time:.2f} req/s")
print(f"Average Response:     {avg_time * 1000:.2f} ms")
print("======================================================")
