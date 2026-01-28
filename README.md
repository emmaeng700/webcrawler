# Web Crawler in Go

## Overview

This is a command‑line internal‑link crawler written in Go. Given a base URL, a maximum concurrency level, and a page limit, the program recursively walks the website, counting how many times each internal page is referenced. A final report lists pages ordered by the number of incoming links.

---

## Learning Goals

- Practice with the Go 1.24 toolchain and modules
- Make efficient HTTP requests from Go
- Parse HTML using the `golang.org/x/net/html` package
- Write unit tests for pure functions (`normalizeURL`, `getURLsFromHTML`, `sortPages`)
- Use goroutines, mutexes, and channels for safe concurrent crawling

---

## Repository Layout

| File                        | Purpose                                            |
| --------------------------- | -------------------------------------------------- |
| `main.go`                   | CLI entry point and argument parsing               |
| `configure.go`              | Builds the shared `config` struct                  |
| `crawl_page.go`             | Recursive concurrent crawler                       |
| `get_html.go`               | Fetches and validates HTML responses               |
| `get_urls_from_html.go`     | Extracts links from HTML                           |
| `normalize_url.go`          | Canonicalises URLs for deduplication               |
| `print_report.go`           | Generates the formatted CLI report                 |
| `*_test.go`                 | Unit tests                                         |
| `dockerfile`                | Multi‑stage build for a small runtime image        |
| `.dockerignore`             | Keeps the build context lean                       |

---

## Concurrency Design

The crawler shares a single `config` struct across goroutines.

```go
 type config struct {
     pages              map[string]int // URL → reference count
     baseURL            *url.URL       // host filter
     mu                 *sync.Mutex    // protects pages
     concurrencyControl chan struct{}  // semaphore for HTTP workers
     wg                 *sync.WaitGroup// waits for all workers to finish
     maxPages           int            // hard crawl cap
 }
```

1. **Goroutine per page**: Each discovered URL spawns `go cfg.crawlPage(nextURL)`.
2. **Back‑pressure**: The buffered channel `concurrencyControl` acts like a semaphore. Before each request the goroutine sends an empty struct into the channel, blocking if the buffer is full. When the request ends, it receives from the channel, freeing a slot.
3. **Race‑free counters**: All reads and writes to the shared `pages` map occur inside a mutex.
4. **Graceful shutdown**: The main goroutine uses a `WaitGroup` so the program exits only after all spawned goroutines are done.
5. **Early termination**: The first line in `crawlPage` exits immediately when the number of tracked pages reaches `maxPages`.

---

## Quick Start

### Prerequisites

* Docker 24 or newer


### Run in Docker (no Go installation required)

```bash
# Build the image 
docker build -t crawler .

# Run the crawler inside the container
docker run --rm crawler https://example.com 5 50
```

If you want a different tag:

```bash
docker build -t crawler:latest .
docker run --rm crawler:latest https://example.com 3 25
```

---

## Command‑line Arguments

```
docker run --rm crawler:latest <baseURL> <maxConcurrency> <maxPages>
```

| Argument          | Example                | Description                                 |
| ----------------- | ---------------------- | ------------------------------------------- |
| `baseURL`         | `https://example.com`  | Root of the site to crawl                   |
| `maxConcurrency`  | `10`                   | Maximum number of concurrent HTTP requests  |
| `maxPages`        | `250`                  | Stop after this many unique pages           |

Start with a low concurrency setting to verify behaviour, then increase it for performance.

---



### Running tests in Docker using the builder stage

The runtime image is distroless and contains no Go tool‑chain. Instead, build the `builder` stage from the Dockerfile and run the tests in that image.

```bash
# Build only the builder stage and tag it
docker build --target builder -t crawler-builder .

# Execute unit tests inside the builder image
docker run --rm -w /app crawler-builder go test ./...
```

## Known limitations

* The crawler does not respect `robots.txt`. Use caution when crawling external domains.
* It retries neither network nor HTTP errors.
* It only processes `text/html` content, ignoring other formats such as PDF or images.



